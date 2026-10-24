package desarrollofullstack.librerias.model;

import jakarta.persistence.*;
import lombok.Data;

@Data
@Entity
@Table(name = "LIBROS")
public class Libros {
    
    @Id
    @GeneratedValue(strategy = GenerationType.SEQUENCE, generator = "seq_libros")
    @SequenceGenerator(name = "seq_libros", sequenceName = "SEQ_LIBROS", allocationSize = 1)
    private Long id;

    @Column(name = "titulo", nullable = false)
    private String titulo;

    @Column(name = "autor", nullable = false)
    private String autor;

    @Column(name = "anio_publicacion", nullable = false)
    private Integer anioPublicacion;

    @Column(name = "genero", nullable = false)
    private String genero;

}
