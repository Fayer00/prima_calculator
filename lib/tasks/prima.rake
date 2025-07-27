# lib/tasks/prima.rake
require 'json'

namespace :prima do
  desc "Calcula la prima de servicios para un empleado a partir de un archivo JSON."
  task :calculate, [:json_file] => :environment do |_, args|
    if args[:json_file].blank?
      puts "Por favor, proporciona la ruta a un archivo JSON."
      puts "Ejemplo: rails prima:calculate['path/to/your/file.json']"
      exit
    end

    file_path = Rails.root.join(args[:json_file])

    unless File.exist?(file_path)
      puts "Error: El archivo no se encuentra en #{file_path}"
      exit
    end

    begin
      json_content = File.read(file_path)
      employee_data = JSON.parse(json_content)

      calculator = PrimaCalculationService.new(employee_data)
      result = calculator.calculate

      puts JSON.pretty_generate(result)

      # Capturamos errores específicos del servicio para dar feedback claro.
    rescue PrimaCalculationService::MissingDataError => e
      puts "Error en los datos: #{e.message}"
    rescue PrimaCalculationService::InvalidDataError => e
      puts "Error en los datos: #{e.message}"
      # Errores generales que no previmos.
    rescue JSON::ParserError
      puts "Error: El archivo no es un JSON válido."
    rescue Errno::ENOENT
      puts "Error: El archivo no se encuentra en #{file_path}"
    rescue => e
      puts "Ocurrió un error inesperado: #{e.message}"
      puts "Clase del error: #{e.class}"
    end
  end
end
