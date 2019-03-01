module Services::Sms
  class Base
    SMS_PROVIDERS = [
      KCELL      = "Kcell"
    ]

    SETTINGS = [
      FALLBACK_PROVIDER_SETTING = "sms_service.fallback_provider",
      DEFAULT_PROVIDER_SETTING = "sms_service.default_provider",
    ]

    def self.phone_normalization_klass
      PhoneNumberString
    end

    # Services::Sms::Base.prepare("+371 20128732", "hello world", "gsm")
    def self.prepare(phone, message, custom_provider=nil)
      provider_to_use = custom_provider.presence ||
        PREFERRED_SENDER_FOR[PhoneNumber::CarrierDetective.call(phone: phone)].call

      Rails.logger.info(
        "--> Services::Sms::Base.prepare(#{ phone }, #{ message }, #{ custom_provider }) "\
        "got '#{ provider_to_use }' provider"
      )

      provider_klass_for(provider_to_use).new(phone, message)
    end

    attr_accessor :phone, :message, :error_code

    def initialize(phone, message)
      self.phone = self.class.phone_normalization_klass.new(phone)
      self.message = message
    end

    def perform_send!
      if ready_to_send?
        response = send_request!(prepare_params)
        self.error_code = parse_response(response)

        error_code.nil? ? success_response : failed_response
      else
        self.error_code = -99
      end

      error_code.nil?
    end

    def get_error
      return if error_code.blank?

      if errors_list.has_key?(error_code)
        return I18n.t(errors_list[error_code], scope: "sms.errors")
      end

      I18n.t(
        "Unidentified error: %{code}",
        default: "Unidentified error: %{code}", scope: "sms.errors",
        code: error_code
      )
    end

    def ready_to_send?
      phone.present?
    end

    protected

    def self.default_provider
      Releaf::Settings[DEFAULT_PROVIDER_SETTING]
    end

    def self.fallback_enabled?
      Releaf::Settings[FALLBACK_PROVIDER_SETTING].present?
    end

    def self.fallback_provider
      provider_klass_for(Releaf::Settings[FALLBACK_PROVIDER_SETTING])
    end

    def self.provider_klass_for(provider_name)
      "Services::Sms::#{ provider_name.camelcase }".constantize
    end

      #== Instance privates ==

    def send_request!(params)
      uri = URI(url)
      uri.query = URI.encode_www_form(params)
      Net::HTTP.get_response(uri)
    end

    def prepare_params
      raise NotImplementedError, "#prepare_params not implemented"
    end

    def url
      config.fetch("uri")
    end

    def parse_response(response)
      raise NotImplementedError, "#parse_response not implemented"
    end

    def errors_list
      {-99 => "Invalid phone number"} # Custom error code
    end

    def provider
      self.class.name.demodulize
    end

    def config
      CONFIG.dig("sms", provider.snakecase)
    end

    def send_through_fallback_service!(error=nil, switch_to_fallback=true)
      switch_default_provider! if switch_to_fallback

      fallback_provider = self.class.fallback_provider.new(phone, message)
      fallback_provider.perform_send!
    end

    def switch_default_provider!
      return unless self.class.fallback_enabled?

      Releaf::Settings[DEFAULT_PROVIDER_SETTING] = Releaf::Settings[FALLBACK_PROVIDER_SETTING]
    end

    def success_response; end
    def failed_response; end
  end
end
