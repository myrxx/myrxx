require 'test_helper'
require 'myrxx'

class MyrxxTest < ActiveSupport::TestCase
  setup do
    @office = MyRxx::Office.new(name: 'api test office')
    @provider = MyRxx::Provider.new(first_name: 'api', last_name: 'provider', email: 'api.provider@example.com')
    @myrxx = MyRxx::Api.new(ENV['MYRXX_CLIENT_ID'], ENV['MYRXX_SECRET'], 'http://localhost:3001/oauth2/callback', @office, @provider, {mode: :local})
    if @myrxx.requires_password?
      @myrxx.login_with_password '123456'
    else
      @myrxx.login_without_password
    end
  end

  test "office to_hash" do
    office_attributes = {id: nil, name: "office name", address: nil, address2: nil, city: nil, state: nil, zip_code: nil, share_patients: nil, application_code: nil}
    assert_equal office_attributes, MyRxx::Office.new(office_attributes).to_hash
  end

  test "provider to_hash" do
    prov = MyRxx::Provider.new(first_name: 'first', last_name: 'last', email: 'api.provider@example.com')
    assert_equal({twitter: nil, facebook_name: nil, facebook_link: nil, prefix: nil, suffix: nil, accreditation: nil, user_attributes: {first_name: "first", last_name: "last", email: "api.provider@example.com"}}, prov.to_hash)
  end

  test "patient to_hash" do
    patient_attributes = {first_name: "first", last_name: "last", email: "api_patient@example.com", is_connected: nil, external_id: nil}
    assert_equal patient_attributes, MyRxx::Patient.new(nil, patient_attributes).to_hash
  end

  test "prescription to_hash" do
    prescription_attributes = {workout: nil, id: nil, instructions: "instr", created_at: nil}
    assert_equal prescription_attributes, MyRxx::Prescription.new(prescription_attributes).to_hash
  end

  test "workout to_hash" do
    workout_attributes = {id: nil, name: nil, difficulty: 3, time_to_complete: 75, body_area_names: ["upper", "lower"], category_names: nil, equipment_names: ["bench"], exercise_names: ["prisoner squat", "bench press"]}
    assert_equal workout_attributes, MyRxx::Workout.new(workout_attributes).to_hash
  end

  test "prescribe_redirect to_hash" do
    prescribe_redirect_attributes = {url: 'url'}
    assert_equal prescribe_redirect_attributes, MyRxx::PrescribeRedirect.new(prescribe_redirect_attributes).to_hash
  end

  test "api login" do
    office = MyRxx::Office.new(name: 'api test office')
    provider = MyRxx::Provider.new(first_name: 'api', last_name: 'provider', email: 'api.provider@example.com')
    myrxx = MyRxx::Api.new(ENV['MYRXX_CLIENT_ID'], ENV['MYRXX_SECRET'], 'http://localhost:3001/oauth2/callback', office, provider, {mode: :local})
    if myrxx.requires_password?
      myrxx.login_with_password '123456'
    else
      myrxx.login_without_password
    end
  end

  test "office" do
    off = @myrxx.office
    assert off.to_hash
  end

  test "patients" do
    pts = @myrxx.patients
    assert pts.map(&:to_hash)
    assert pts.first.to_hash[:id].nil?
  end

  test "patent" do
    id = @myrxx.patients.first.id
    assert_equal id, @myrxx.patient(id).id
  end

  test "patient find by email" do
    pt = @myrxx.patients.first
    assert_equal pt.email, @myrxx.patient(email: pt.email).email
  end

  test "patient_create" do
    pt = MyRxx::Patient.new(@myrxx, first_name: 'first', last_name: 'last', email: 'test@example.com')
    assert pt.save
  end

  test "patient_update" do
    assert @myrxx.patients.first.save
  end

  test "patient prescribe" do
    assert !@myrxx.patients.first.prescribe.url.blank?
  end

  test "patient prescriptions" do
    assert @myrxx.patients.first.prescriptions.map(&:to_hash)
  end

  test "create patient with error" do
    pt = MyRxx::Patient.new(@myrxx)
    pt.save
    assert pt.errors.is_a?(Array)
    ["Last name can't be blank", "Email can't be blank"].each do |m|
      assert pt.errors.include?(m)
    end
  end

  test "update patient with error" do
    pt = @myrxx.patients.first
    pt.email = nil
    pt.save
    ["Email can't be blank"].each do |m|
      assert pt.errors.include?(m)
    end
  end
end
