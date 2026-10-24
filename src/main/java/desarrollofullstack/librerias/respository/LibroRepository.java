package desarrollofullstack.librerias.respository;

import org.springframework.data.jpa.repository.JpaRepository;

import desarrollofullstack.librerias.model.Libros;

public interface LibroRepository extends JpaRepository<Libros, Long> {
}
