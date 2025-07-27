# README

Requisitos Previos
Asegúrate de tener instalado el siguiente software en tu sistema:

- Ruby (v3.2.3 o superior recomendado)

- Bundler (manejador de gemas de Ruby)

- Rails (v7.0 o superior)

Pasos para ejecucion

- Extrae o clona el repositorio
- cd prima_calculator
- bundle install
- El projecto incluye un employee_data.json en su raiz. Para ejecutar ```rails 'prima:calculate[employee_data.json]' ```

- Otro metodo de ejecucion:

```ruby
datos_empleado = {
                  "nombre" => "Juan Pérez",
           "fecha_ingreso" => "2023-03-15",
      "salarios_mensuales" => {
         "enero" => 3000000,
       "febrero" => 3000000,
         "marzo" => 3000000,
         "abril" => 3200000,
          "mayo" => 3200000,
         "junio" => 3200000,
         "julio" => 3200000,
        "agosto" => 3200000,
    "septiembre" => 3500000,
       "octubre" => 3500000,
     "noviembre" => 3500000,
     "diciembre" => 3500000
  },
         "periodo_calculo" => "primer_semestre",
  "metodo_calculo_salario" => "promedio",
"ausencias_no_remuneradas" => [
    "2025-04-12",
    "2025-04-15"
  ]
}
calculadora = PrimaCalculationService.new(datos_empleado)
resultado = calculadora.calculate
```

- Para correr tests ``` bundle exec rspec ```


Clases Principales y Decisiones de Diseño

- PrimaCalculationService, Decidi seguir con el patron de diseño de Services Object dada a la naturaleza de buk y mi experiencia en Webdox
donde busco encapsular todo lo relacionado con este calculo para Colombia en un solo lugar. Esto ayuda a la reutilizacion del codigo en diferentes lugares de la APP
, ayuda con los Tests debido a que las reglas de negocio (calculo prima) estan aisladas en un solo lugar

- MissingDataError y InvalidDataError, Son errores personalizados para dar un feedback en la Rake Task, esto con el objectivo de dar la informacion 
necesaria para una rapida identificacion del problema

- Rake Task, Como se pide una App CLI opte por las tareas Rake dado que estas ejecutan Scripts donde se tiene acceso al entorno necesario a la hora de ejecutar.
las rake task son una buena practica cuando uno quiere hacer cambios en un ambiente productivo de manera segura, sin dar acceso directo a los servidores