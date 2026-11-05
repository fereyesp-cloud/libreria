package desarrollofullstack.librerias.controller;


import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;


import desarrollofullstack.librerias.model.Libros;
import desarrollofullstack.librerias.service.LibroService;
import java.util.List;


@RestController
@RequestMapping("/api/libros")
@CrossOrigin(origins = "*")
public class LibroController {
    
    private final LibroService libroService;

    public LibroController(LibroService libroService ){
        this.libroService = libroService;
    }

    @GetMapping("/{id}")
    public ResponseEntity<Libros> obtenerLibro(@PathVariable Long id) {
        return libroService.buscarPorId(id)
            .map(ResponseEntity::ok)
            .orElse(ResponseEntity.notFound().build());
    }

   @PostMapping
    public ResponseEntity<Libros> crearLibro(@RequestBody Libros libro) {
        Libros creado = libroService.crear(libro);
        return ResponseEntity.status(HttpStatus.CREATED).body(creado);
    }

   @PutMapping("/{id}")
    public ResponseEntity<Libros> actualizarLibro(@PathVariable Long id, @RequestBody Libros libro) {
        return libroService.actualizar(id, libro)
            .map(ResponseEntity::ok)
            .orElse(ResponseEntity.notFound().build());
    }

   @DeleteMapping("/{id}")
    public ResponseEntity<Void> eliminarLibro(@PathVariable Long id) {
        if (libroService.eliminar(id)) {
            return ResponseEntity.noContent().build();
        }
        return ResponseEntity.notFound().build();
    }

    @GetMapping
    public ResponseEntity<List<Libros>> listar() {
        return  ResponseEntity.ok(libroService.listar());
    }
}
