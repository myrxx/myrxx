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
    office_attributes = {name: 'office name'}
    assert_equal office_attributes, MyRxx::Office.new(office_attributes).to_hash
  end

  test "provider to_hash" do
    prov = MyRxx::Provider.new(first_name: 'first', last_name: 'last', email: 'api.provider@example.com')
    assert_equal({user_attributes: {first_name: 'first', last_name: 'last', email: 'api.provider@example.com'}}, prov.to_hash)
  end

  test "patient to_hash" do
    patient_attributes = {first_name: 'first', last_name: 'last', email: 'api_patient@example.com'}
    assert_equal patient_attributes, MyRxx::Patient.new(nil, patient_attributes).to_hash
  end

  test "prescription to_hash" do
    prescription_attributes = {instructions: 'instr'}
    assert_equal prescription_attributes, MyRxx::Prescription.new(prescription_attributes).to_hash
  end

  test "workout to_hash" do
    workout_attributes = {difficulty: 3, time_to_complete: 75, body_area_names: ['upper', 'lower'], equipment_names: ['bench'], exercise_names: ['prisoner squat', 'bench press']}
    assert_equal workout_attributes, MyRxx::Workout.new(workout_attributes).to_hash
  end

  test "prescribe_redirect to_hash" do
    prescribe_redirect_attributes = {url: 'url'}
    assert_equal prescribe_redirect_attributes, MyRxx::PrescribeRedirect.new(prescribe_redirect_attributes).to_hash
  end

  test "api login" do
    office = MyRxx::Office.new(name: 'api test office')
    provider = MyRxx::Provider.new(first_name: 'api', last_name: 'provider', email: 'api.provider@example.com')
    myrxx = MyRxx::Api.new('1cb123197f39bbb643321bb66d316cbc7f5f8d81ffd0eb992b586e5be46339fe', '7c25df431204f75141b5eb383898e228d5b1804f76b7abccfcbd966c07c4bce4', 'http://localhost:3001/oauth2/callback', office, provider, {mode: :local})
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
    assert_equal pt.id, @myrxx.patient(email: pt.email).id
  end

  test "patient_create" do
    assert @myrxx.patients.first.save
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
end
