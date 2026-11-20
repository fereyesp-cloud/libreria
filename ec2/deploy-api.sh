#!/usr/bin/env bash
set -Eeuo pipefail

# Se ejecuta DENTRO de la EC2 (lo envía deploy-to-instance.sh por Systems Manager).
# Descarga la imagen, el wallet (S3) y las credenciales (Secrets Manager) y
# reemplaza el contenedor de la API, con rollback automático si algo falla.

image="${1:?image URI is required}"
region="${2:?AWS region is required}"
secret_arn="${3:?Oracle credentials secret ARN is required}"
wallet_bucket="${4:?Oracle wallet bucket is required}"
wallet_key="${5:?Oracle wallet object key is required}"

if [[ ! "$image" =~ ^[0-9]{12}\.dkr\.ecr\.[a-z0-9-]+\.amazonaws\.com/librerias-back:[0-9a-f]{40}$ ]]; then
  echo "Invalid API ECR image URI." >&2
  exit 2
fi
if [[ ! "$region" =~ ^[a-z0-9-]+$ \
  || ! "$secret_arn" =~ ^arn:aws:secretsmanager:${region}:[0-9]{12}:secret:[A-Za-z0-9/_+=.@-]+$ \
  || ! "$wallet_bucket" =~ ^[a-z0-9][a-z0-9.-]{1,61}[a-z0-9]$ \
  || ! "$wallet_key" =~ ^[A-Za-z0-9._/-]{1,1024}$ ]]; then
  echo "Invalid Oracle resource identifier." >&2
  exit 2
fi

registry="${image%%/*}"
docker_config="$(mktemp -d /tmp/biblioteca-ecr-docker.XXXXXX)"
env_file="$(mktemp /tmp/biblioteca-api-env.XXXXXX)"
wallet_zip="$(mktemp /tmp/biblioteca-wallet.XXXXXX)"
wallet_dir="/opt/biblioteca/wallet"
export DOCKER_CONFIG="$docker_config"
cleanup() {
  if [[ -n "$docker_config" ]]; then
    rm -rf -- "$docker_config"
    docker_config=""
  fi
  if [[ -n "$env_file" ]]; then
    rm -f -- "$env_file"
    env_file=""
  fi
  if [[ -n "$wallet_zip" ]]; then
    rm -f -- "$wallet_zip"
    wallet_zip=""
  fi
}
trap cleanup EXIT

aws ecr get-login-password --region "$region" \
  | docker login --username AWS --password-stdin "$registry" >/dev/null
docker pull "$image"
docker logout "$registry" >/dev/null 2>&1 || true
rm -f -- "$docker_config/config.json"

# Wallet: se descarga de S3 y se descomprime en la EC2 (solo root puede leerlo).
# Se monta en el contenedor como solo lectura; nunca entra a la imagen ni a Git.
aws s3 cp "s3://${wallet_bucket}/${wallet_key}" "$wallet_zip" \
  --region "$region" --only-show-errors
rm -rf -- "${wallet_dir}.new"
mkdir -p "${wallet_dir}.new"
python3 -c 'import sys, zipfile; zipfile.ZipFile(sys.argv[1]).extractall(sys.argv[2])' \
  "$wallet_zip" "${wallet_dir}.new"
if [[ ! -f "${wallet_dir}.new/tnsnames.ora" ]]; then
  echo "The wallet ZIP does not contain tnsnames.ora at its root." >&2
  exit 1
fi
rm -rf -- "$wallet_dir"
mv -- "${wallet_dir}.new" "$wallet_dir"
chmod -R go-rwx "$wallet_dir"

# Credenciales: se leen de Secrets Manager a un archivo temporal (600) que se borra al terminar.
aws secretsmanager get-secret-value \
  --secret-id "$secret_arn" \
  --query SecretString \
  --output text \
  --region "$region" \
  | python3 -c '
import json
import sys

secret = json.load(sys.stdin)
with open(sys.argv[1], "w", encoding="utf-8") as output:
    for key in ("DB_URL", "DB_USERNAME", "DB_PASSWORD"):
        value = secret.get(key)
        if not isinstance(value, str) or "\n" in value or "\r" in value:
            raise SystemExit(f"Secret is missing a valid {key} value.")
        output.write(f"{key}={value}\n")
' "$env_file"
printf 'TNS_ADMIN=/app/wallet\n' >> "$env_file"
chmod 600 "$env_file"

backup=""
new_container_attempted=false
rollback() {
  status=$?
  trap - EXIT
  if (( status != 0 )); then
    if [[ "$new_container_attempted" == true ]] && docker inspect biblioteca-api >/dev/null 2>&1; then
      docker rm -f biblioteca-api >/dev/null
    fi
    if [[ -n "$backup" ]] && docker inspect "$backup" >/dev/null 2>&1; then
      docker rename "$backup" biblioteca-api
      docker start biblioteca-api
      echo "API deployment failed; previous container restored." >&2
    fi
  fi
  cleanup
  exit "$status"
}
trap rollback EXIT

if docker inspect biblioteca-api >/dev/null 2>&1; then
  backup="biblioteca-api-rollback-$(date +%s%N)"
  docker rename biblioteca-api "$backup"
  docker stop "$backup" >/dev/null || true
fi

new_container_attempted=true
docker run -d \
  --name biblioteca-api \
  --restart unless-stopped \
  --publish 127.0.0.1:8080:8080 \
  --env-file "$env_file" \
  --volume "${wallet_dir}:/app/wallet:ro" \
  "$image" >/dev/null
rm -f -- "$env_file"
env_file=""

healthy=false
for attempt in $(seq 1 60); do
  if curl --fail --silent --show-error --max-time 10 http://127.0.0.1:8080/api/libros \
    | python3 -c 'import json,sys; libros=json.load(sys.stdin); assert isinstance(libros,list)'; then
    healthy=true
    break
  fi
  sleep 5
done
if [[ "$healthy" != true ]]; then
  echo "API health check failed: /api/libros did not return a JSON list." >&2
  docker logs --tail 50 biblioteca-api >&2 || true
  exit 1
fi

if [[ -n "$backup" ]]; then
  docker rm "$backup" >/dev/null
fi
backup=""
cleanup
trap - EXIT
echo "API deployed successfully: $image"
