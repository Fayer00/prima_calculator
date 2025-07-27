# app/services/prima_calculation_service.rb
require "date"

# Excepciones personalizadas para el servicio de cálculo de prima
class PrimaServiceError < StandardError; end
class MissingDataError < PrimaServiceError; end
class InvalidDataError < PrimaServiceError; end
class PrimaCalculationService
  # UVT y límites para el año 2025
  UVT_VALUE = 49799.0 # Valor UVT para 2025 https://www.dian.gov.co/normatividad/Normatividad/Resoluci%C3%B3n%20000193%20de%2004-12-2024.pdf
  EXEMPT_INCOME_LIMIT_UVT = 790.0
  WITHHOLDING_TAX_THRESHOLD_UVT = 95.0

  # Tabla de Retención del Art. 383 E.T. para 2025 https://www.itscontable.com/blog/retencion-en-la-fuente-de-asalariados-2025/
  WITHHOLDING_TABLE = [
    { min_uvt: 360, max_uvt: Float::INFINITY, rate: 0.39, fixed_fee_uvt: 770 },
    { min_uvt: 2300, max_uvt: Float::INFINITY, rate: 0.37, fixed_fee_uvt: 268 },
    { min_uvt: 945, max_uvt: 2300, rate: 0.35, fixed_fee_uvt: 162 },
    { min_uvt: 640, max_uvt: 945, rate: 0.33, fixed_fee_uvt: 69 },
    { min_uvt: 150, max_uvt: 360, rate: 0.28, fixed_fee_uvt: 10 },
    { min_uvt: 95, max_uvt: 150, rate: 0.19, fixed_fee_uvt: 0 },
    { min_uvt: 0, max_uvt: 95, rate: 0.0, fixed_fee_uvt: 0 }
  ].freeze

  attr_reader :employee_data

  def initialize(employee_data)
    @employee_data = employee_data
    validate_data! # Validar los datos de entrada
  end

  def calculate
    # Determinar las fechas del semestre
    semester_start, semester_end = semester_dates

    # Calcular los días trabajados
    worked_days = calculate_worked_days(semester_start, semester_end)

    # Calcular el salario base
    base_salary = calculate_base_salary(semester_start)

    # Calcular la prima bruta
    gross_bonus = (base_salary * worked_days) / 360.0

    # Calcular la renta exenta
    exempt_income = calculate_exempt_income(gross_bonus)

    # Calcular la base gravable
    taxable_base = gross_bonus - exempt_income

    # Calcular el impuesto
    withholding_tax = calculate_withholding_tax(taxable_base)

    # Formatear la salida
    {
      empleado: employee_data["nombre"],
      periodo_calculo: employee_data["periodo_calculo"],
      salario_base_prima: base_salary.round(2),
      dias_trabajados_semestre: worked_days,
      prima_bruta: gross_bonus.round(2),
      renta_exenta_25_por_ciento: exempt_income.round(2),
      base_gravable_impuesto: taxable_base.round(2),
      impuesto_retenido: withholding_tax.round(2),
      prima_neta: (gross_bonus - withholding_tax).round(2)
    }
  end

  private

  def validate_data!
    # Verificamos la presencia de las llaves principales.
    required_keys = %w[nombre fecha_ingreso salarios_mensuales periodo_calculo metodo_calculo_salario]
    required_keys.each do |key|
      raise MissingDataError, "Falta la llave '#{key}' en los datos de entrada." unless employee_data.key?(key)
    end

    # Validamos que el valor de `fecha_ingreso` sea una fecha válida.
    begin
      Date.parse(employee_data['fecha_ingreso'])
    rescue Date::Error
      raise InvalidDataError, "El formato de 'fecha_ingreso' no es válido."
    end

    # Validamos que los salarios mensuales sean numéricos.
    unless employee_data['salarios_mensuales'].values.all? { |s| s.is_a?(Numeric) }
      raise InvalidDataError, "Todos los salarios mensuales deben ser valores numéricos."
    end
  end

  # Determina las fechas de inicio y fin del semestre basándose en el período de cálculo.
  def semester_dates
    year = Date.today.year
    if employee_data["periodo_calculo"] == "primer_semestre"
      [ Date.new(year, 1, 1), Date.new(year, 6, 30) ]
    else
      [ Date.new(year, 7, 1), Date.new(year, 12, 31) ]
    end
  end

  # Calcula los días trabajados, considerando la fecha de ingreso del empleado
  # y descontando las ausencias no remuneradas que caen dentro del semestre.
  def calculate_worked_days(semester_start, semester_end)
    entry_date = Date.parse(employee_data["fecha_ingreso"])
    # La fecha de inicio real para el cálculo es la más reciente entre el inicio del semestre y la fecha de ingreso.
    start_date = [ semester_start, entry_date ].max

    total_days = (semester_end - start_date).to_i + 1
    # Usamos `count` con un bloque para contar solo las ausencias que pertenecen al período de cálculo.
    unpaid_absences = employee_data["ausencias_no_remuneradas"].count do |absence|
      absence_date = Date.parse(absence)
      absence_date >= start_date && absence_date <= semester_end
    end

    total_days - unpaid_absences
  end

  # Determina el salario base según uno de los dos métodos: "actual" o "promedio".
  def calculate_base_salary(semester_start)
    salaries = employee_data["salarios_mensuales"]

    if employee_data["metodo_calculo_salario"] == "actual"
      # Salario del último mes del semestre
      if employee_data["periodo_calculo"] == "primer_semestre"
        salaries["junio"]
      else
        salaries["diciembre"]
      end
    else # Promedio
      semester_months = if employee_data["periodo_calculo"] == "primer_semestre"
                          %w[enero febrero marzo abril mayo junio]
                        else
                          %w[julio agosto septiembre octubre noviembre diciembre]
                        end
      # Se filtran los salarios de esos meses y se calcula el promedio.
      relevant_salaries = salaries.slice(*semester_months).values
      relevant_salaries.sum / relevant_salaries.size.to_f
    end
  end

  # Calcula el 25% de renta exenta, asegurándose de que no supere el límite anual en UVT.
  # EXEMPT_INCOME_LIMIT_UVT * UVT_VALUE: Calcula el límite máximo anual de la exención en pesos colombianos (790 UVT multiplicado por el valor de una UVT)
  def calculate_exempt_income(gross_bonus)
    [ gross_bonus * 0.25, EXEMPT_INCOME_LIMIT_UVT * UVT_VALUE ].min
  end

  # Calcula el impuesto de retención aplicando la tabla del Art. 383.
  def calculate_withholding_tax(taxable_base)
    return 0 if taxable_base <= 0 # No hay impuesto si la base gravable es cero o negativa

    # Convertimos la base gravable de COP a UVT para poder usar la tabla.
    taxable_base_uvt = taxable_base / UVT_VALUE

    return 0 if taxable_base_uvt <= WITHHOLDING_TAX_THRESHOLD_UVT # No hay impuesto si la base gravable es menor o igual al umbral de impuesto.

    # Buscamos el nivel de impuesto correspondiente en la tabla. Si no lo encontramos, consideramos el último nivel.
    tier = WITHHOLDING_TABLE.find { |t| taxable_base_uvt > t[:min_uvt] && taxable_base_uvt <= t[:max_uvt] }

    # Convertimos el impuesto en UVT a COP y lo redondeamos a dos decimales.
    if tier
      tax_in_uvt = ((taxable_base_uvt - tier[:min_uvt]) * tier[:rate]) + tier[:fixed_fee_uvt]
      (tax_in_uvt * UVT_VALUE).round
    else
      0
    end
  end
end