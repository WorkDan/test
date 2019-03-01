module Services
  module SoapAdapters
    module Base
      attr_accessor :response, :error

      REQUEST_FAILURE = :request_failed
      RESOURCE_NOT_FOUND = :resource_not_found

      def success?
        request_succeeded? && resource_found?
      end

      private

      def response_data(*path)
        return unless response.respond_to?(:to_hash)

        path.inject(response.to_hash) { |result, part| result.try(:[], part) }
      end

      def request_succeeded?
        response && response.success?
      end

      def perform_request(timeout_count=15)
        begin
          Timeout.timeout(timeout_count) do
            call_soap
            try_to_parse_response
            yield if block_given? && success?
          end
        rescue => e
          @response = nil
          Rails.logger.error("SOAP request failed: #{ e }")
        end

        set_errors
      end

      def call_soap
        @response = soap_client.call(soap_action, savon_action_options)
      end

      def savon_action_options
        {message: soap_message}.merge(custom_savon_action_options)
      end

      def custom_savon_action_options
        {}
      end

      def try_to_parse_response
        response.try(:to_hash)
      end

      def set_errors
        @error = REQUEST_FAILURE unless request_succeeded?
        @error ||= RESOURCE_NOT_FOUND unless resource_found?
      end

      def soap_client
        @soap_client ||= Savon.client(savon_client_options)
      end

      def savon_client_options
        {
          wsdl: config(:service_uri),
          adapter: :net_http,
          log: false,
        }.merge(custom_savon_client_options)
      end

      def custom_savon_client_options
        {}
      end

      def mapped_keys_for(collection)
        if collection.is_a?(Array)
          collection.map do |collection_item|
            map_keys(collection_item)
          end
        else
          map_keys(collection)
        end
      end

      def map_keys(collection)
        collection.inject({}) do |result, (key, value)|
          new_key = key_map[key]
          result[new_key] = value if new_key
          result
        end
      end

      def xlsx_to_zip(spreadsheet, file_name)
        temp_zip = FileZipping.zip_file(spreadsheet, file_name)
        @debtors_list.update_attributes(file: temp_zip, file_name: "creditinfo_debtors_#{ Date.today.strftime("%Y-%m-%d") }", file_created_at: Time.now)
        temp_zip.unlink
      end
    end
  end
end
