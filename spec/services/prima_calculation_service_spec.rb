# spec/services/prima_calculation_service_spec.rb

require 'rails_helper'


RSpec.describe PrimaCalculationService, type: :service do
  let(:base_employee_data) do
    {
      "nombre" => "Empleado de Prueba",
      "fecha_ingreso" => "2023-01-01",
      "salarios_mensuales" => {
        "enero" => 4000000, "febrero" => 4000000, "marzo" => 4000000,
        "abril" => 4200000, "mayo" => 4200000, "junio" => 4200000,
        "julio" => 4200000, "agosto" => 4500000, "septiembre" => 4500000,
        "octubre" => 4500000, "noviembre" => 4500000, "diciembre" => 4500000
      },
      "periodo_calculo" => "primer_semestre",
      "metodo_calculo_salario" => "promedio",
      "ausencias_no_remuneradas" => []
    }
  end


  context "cuando se calcula la prima del primer semestre" do
    it "calcula correctamente con salario promedio" do
      data = base_employee_data.merge({
                                        "periodo_calculo" => "primer_semestre",
                                        "metodo_calculo_salario" => "promedio"
                                      })

      result = described_class.new(data).calculate

      expect(result[:salario_base_prima]).to eq(4100000)
      expect(result[:dias_trabajados_semestre]).to eq(181)
      expect(result[:prima_bruta]).to be_within(0.01).of(2061388.89)
      expect(result[:impuesto_retenido]).to be_within(0.01).of(0)
    end

    it "descuenta los días de ausencia" do
      data = base_employee_data.merge({
                                        "periodo_calculo" => "primer_semestre",
                                        "metodo_calculo_salario" => "promedio",
                                        "ausencias_no_remuneradas" => ["2025-03-10", "2025-04-22"]
                                      })

      result = described_class.new(data).calculate

      expect(result[:dias_trabajados_semestre]).to eq(179)
    end

    it "calcula la prima proporcional para un nuevo empleado" do
      data = base_employee_data.merge({
                                        "fecha_ingreso" => "2025-03-15",
                                        "periodo_calculo" => "primer_semestre",
                                        "metodo_calculo_salario" => "promedio"
                                      })

      result = described_class.new(data).calculate
      dias_esperados = (Date.new(2025, 6, 30) - Date.new(2025, 3, 15)).to_i + 1

      expect(result[:dias_trabajados_semestre]).to eq(dias_esperados)
    end
  end

  context "cuando se calcula la retención en la fuente" do
    it "aplica el impuesto para salarios altos" do
      high_salary = 30000000
      high_salary_data = base_employee_data.merge({
                                                    "salarios_mensuales" => Hash.new(high_salary),
                                                    "periodo_calculo" => "primer_semestre",
                                                    "metodo_calculo_salario" => "actual"
                                                  })

      result = described_class.new(high_salary_data).calculate
      expect(result[:impuesto_retenido]).to be > 0
    end
  end

  context "cuando los datos son inválidos" do
    it "lanza un error si faltan datos clave" do
      data = { "nombre" => "Test" }
      expect {
        described_class.new(data).calculate
      }.to raise_error(MissingDataError)
    end

    it "lanza un error si la fecha es inválida" do
      data = base_employee_data.merge({ "fecha_ingreso" => "fecha-invalida" })

      expect {
        described_class.new(data)
      }.to raise_error(InvalidDataError)
    end
  end
end