require 'oauth2'

module MyRxx
  LOCAL_SERVER_URL = 'http://myrxx.dev'
  TEST_SERVER_URL = 'http://myrxx-dev.herokuapp.com'
  PRODUCTION_SERVER_URL = 'https://myrxx.com'

  API_VERSION = '2'

  class ApiObject
    def self.attributes(*attribs)
      attribs.each do |attrib|
        attr_accessor attrib
        _attributes << attrib
      end
    end

    def initialize(values)
      self.attributes = values
    end

    def attributes=(values)
      values.each {|k, v| send("#{k}=", v) }
    end

    def to_hash
      {}.tap {|hash| attributes.each {|attrib| hash[attrib] = send(attrib) } }
    end
  
    def self._attributes
      (@attributes ||= {})[name] ||= []
    end
  
    def attributes
      self.class._attributes
    end
  end
  
  class Office < ApiObject
    attributes :id, :name, :address, :address2, :city, :state, :zip_code, :share_patients, :application_code
  end
  
  class Provider < ApiObject
    attributes :first_name, :last_name, :email, :twitter, :facebook_name, :facebook_link, :prefix, :suffix, :accreditation

    def to_hash
      super.tap do |hash|
        user_attributes = {}
        [:first_name, :last_name, :email].each do |attrib|
          unless (val = hash.delete(attrib)).blank?
            user_attributes[attrib] = val
          end
        end
        hash[:user_attributes] = user_attributes
      end
    end
  end

  class ApiPersistentObject < ApiObject
    attributes :id

    def self.save_method
      "#{name.split('::').last.downcase}_update"
    end

    def initialize(api, values = {})
      @api = api
      super(values)
    end

    def to_hash
      super.tap {|hash| hash.delete(:id) }
    end

    def save
      begin
        @api.send self.class.save_method, self
      rescue OAuth2::Error => e
        @errors = JSON.parse(e.response.body)['message'].split("\n")
      end
    end

    def errors
      @errors
    end
  end

  class Patient < ApiPersistentObject
    attributes :first_name, :last_name, :email, :is_connected, :external_id

    def attributes=(values)
      [:is_connected?, "is_connected?"].each do |k|
        if v = values.delete(k)
          values[:is_connected] = v
        end
      end
      super(values)
    end

    def prescribe
      @api.prescribe_patient self
    end

    def prescriptions
      @api.patient_prescriptions self
    end
  end

  class Prescription < ApiObject
    attributes :id, :instructions, :created_at, :workout

    def attributes=(values)
      values = values.dup
      workout_hash = values.delete(:workout) || values.delete("workout")
      super(values)
      self.workout = Workout.new workout_hash if workout_hash
    end
  end
  
  class Workout < ApiObject
    attributes :id, :name, :difficulty, :time_to_complete, :body_area_names, :category_names, :equipment_names, :exercise_names
  end
  
  class PrescribeRedirect < ApiObject
    attributes :url
  end

  class Api
    def initialize(client_id, client_secret, redirect_uri, office, provider, options = {})
      @server_url = case (options[:mode] || :production).to_sym
        when :local then LOCAL_SERVER_URL
        when :test then TEST_SERVER_URL
        else PRODUCTION_SERVER_URL
      end
      @client = OAuth2::Client.new(client_id, client_secret, site: @server_url)
      @office = office
      @provider = provider
    end

    def login_with_access_token(access_token_hash)
      @access_token = OAuth2::AccessToken.from_hash access_token_hash
    end

    def login_with_password(password)
      @access_token = @client.password.get_token(@provider.email, password)
    end

    def login_without_password
      @access_token = if @office.application_code.blank?
        @client.password.get_token('', '', office: @office.to_hash, provider: @provider.to_hash)
      else
        @client.password.get_token('', '', office_code: @office.application_code, provider: @provider.to_hash)
      end
    end

    def requires_password?
      provider_exists? @provider.email
    end

    def office
      # GET /api/v2/office
      # returns data for current office
      Office.new get(path_for :office).parsed["office"]
    end

    def provider_exists?(email)
      # GET /api/v2/providers/exists
      # response with status code 2xx if found or 404 if not found
      begin
        response = @client.request :get, path_for(:providers, :exists), params: {email: email, client_id: @client.id, client_secret: @client.secret}
      rescue => e
        if e.respond_to?(:response) && e.response.status == 404
          response = nil
        else
          raise e
        end
      end
    end

    def patients
      # GET /api/v2/patients
      # returns array of patients
      [].tap do |pts|
        get(path_for :patients).parsed.each {|hash| pts << Patient.new(self, hash["patient"]) }
      end
    end

    def new_patient(attributes_hash)
      # returns unsaved patient
      Patient.new(self, attributes_hash)
    end

    def create_patient(attributes_hash)
      # returns saved patient
      new_patient(attributes_hash).save
    end

    def patient_update(patient)
      # if patient has an id (has been saved previously) then
      #   PUT /api/v2/patients/:id
      # else
      #   POST /api/v2/patients
      # returns patient
      patient.attributes = case
        when patient.id then put path_for(:patients, patient.id), patient: patient.to_hash
        else post path_for(:patients), patient: patient.to_hash
      end.parsed["patient"]
      patient
    end

    def patient(id_or_hash)
      # if id is a hash then assume it is search criteria
      #   valid options: email or external_id
      #   GET /api/v2/patients/find?email=user@somedomain.com
      #   or
      #   GET /api/v2/patients/find?external_id=12345
      # or
      #   GET /api/v2/patients/12345
      #   where id_or_hash == 12345
      # returns patient
      Patient.new self, case
        when id_or_hash.is_a?(Hash) then get path_for(:patients, :find), id_or_hash
        else get path_for :patients, id_or_hash
      end.parsed["patient"]
    end

    def prescribe_patient(patient)
      # GET /api/v2/patients/prescriptions/new
      # returns prescriberedirect
      PrescribeRedirect.new get(path_for :patients, patient.id, :prescriptions, :new).parsed["prescriberedirect"]
    end

    def patient_prescriptions(patient)
      # get /api/v2/patients/prescriptions
      # restuns array of prescriptions
      get(path_for :patients, patient.id, :prescriptions).parsed.each {|hash| Prescription.new hash["prescription"] }
    end

    private

    def get(path, params = {})
      @access_token.get(path, params: params) rescue nil
    end

    def post(path, params = {})
      @access_token.post(path, params: params)
    end

    def put(path, params)
      @access_token.put(path, params: params)
    end

    def delete(path, params)
      @access_token.delete(path, params: params)
    end

    def path_for(*parts)
      path = "api/v#{API_VERSION}"
      parts.each {|part| path = "#{path}/#{part}" }
      path
    end
  end
end
