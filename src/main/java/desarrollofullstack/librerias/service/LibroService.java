package desarrollofullstack.librerias.service;

import java.util.Optional;

import org.springframework.stereotype.Service;

import lombok.RequiredArgsConstructor;

import desarrollofullstack.librerias.model.Libros;
import desarrollofullstack.librerias.respository.*;

@Service
@RequiredArgsConstructor
public class  LibroService {

    private final LibroRepository libroRepository;
     // GET: buscar por ID 
    public Optional<Libros> buscarPorId(Long id) {
        return libroRepository.findById(id);
    }

    // POST: crear un libro nuevo
    public Libros crear(Libros libro) {
        Libros guardado = libroRepository.save(libro);
        return guardado;
    }

    // PUT: actualizar un libro existente
    public Optional<Libros> actualizar(Long id, Libros datosNuevos) {
        return libroRepository.findById(id)
            .map(libroExistente -> {
                libroExistente.setTitulo(datosNuevos.getTitulo());
                libroExistente.setAutor(datosNuevos.getAutor());
                libroExistente.setAnioPublicacion(datosNuevos.getAnioPublicacion());
                libroExistente.setGenero(datosNuevos.getGenero());
                return libroRepository.save(libroExistente);
            });
    }   

    // DELETE: eliminar por ID
    public boolean eliminar(Long id) {
        if (!libroRepository.existsById(id)) {
            return false;
        }
        libroRepository.deleteById(id);
        return true;
    }

   
}