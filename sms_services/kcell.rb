module Services::Sms
  class Kcell < Base

    def send_request!(params)
      uri = URI(url)

      http = Net::HTTP.new(uri.host)
      request = Net::HTTP::Post.new(uri.request_uri, headers)
      request.basic_auth(config["username"], config["password"])
      request.body = params.to_json
      http.request(request)
    end
    

    def self.phone_normalization_klass
      PhoneNumbers::Kcell
    end

    protected

    def url
      "#{ super }/messages"
    end

    def parse_response(response)
      return if !response.body
    end

    def prepare_params
      {
        "client_message_id": current_uid,
        "sender": config["from"],
        "recipient": phone,
        "message_text": message,
        "time_bounds": config["time_bounds"]
      }
    end

    private
      def current_uid
        Time.now.to_f
      end

      def headers
        { 'Content-Type' => 'application/json' }
      end
  end
end
