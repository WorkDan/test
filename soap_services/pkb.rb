module Services
  module SoapAdapters
    class Pkb
      include Services::SoapAdapters::Base

      attr_reader :data
      attr_reader :iin, :id_number_type, :culture

      FULL_REPORT_TYPE = 6
      STANDART_REPORT_TYPE = 4
      HAVE_NOT_FULL_REPORT_FOR_THIS_CLIENT_ERROR = 'Не существует запрашиваемого отчета для данного субъекта'

      def initialize(iin, id_number_type, culture='ru-Ru', key_map={})
        @iin                = iin
        @id_number_type     = id_number_type
        @culture            = culture
        @report_import_code = FULL_REPORT_TYPE

        self
      end

      def fetch
        fetch_report

        if error_message?(HAVE_NOT_FULL_REPORT_FOR_THIS_CLIENT_ERROR)
          @report_import_code = STANDART_REPORT_TYPE
          fetch_report
        end

        self
      end

      private

      attr_accessor :report_import_code

      def fetch_report
        perform_request do
          fetch_general_information
        end
      end

      def soap_action
        :get_report
      end

      def savon_client_options
        {
          wsdl: config(:service_uri),
          adapter: :net_http,
          env_namespace: :x,
          namespace_identifier: :ws,
          ssl_verify_mode: :none
        }
      end

      def soap_message
        xml_body
      end

      def custom_savon_action_options
        { soap_header: xml_header }
      end

      def xml_body
        xml = Builder::XmlMarkup.new
        xml.ws :reportId, 0
        xml.ws :doc do
          xml.keyValue do
            xml.reportImportCode report_import_code
            xml.idNumber iin
            xml.idNumberType id_number_type
            xml.consentConfirmed 1
          end
        end
      end

      def xml_header
        xml = Builder::XmlMarkup.new
        xml.ws :CigWsHeader do
          xml.ws :Culture, culture
          xml.ws :UserName, config(:username)
          xml.ws :Password, config(:password)
        end
      end

      def resource_found?
        request_succeeded? && (raw_collection[:cig_result].present? || raw_collection[:cig_result_error].present?)
      end

      def raw_collection
        response_data(:get_report_response, :get_report_result) || {}
      end
      
      def fetch_general_information
        if report_exist?
          @data = {
            general_information: raw_collection.try(:[], :cig_result).try(:[], :result).try(:[], :root).try(:[], :header) || {},
            existing_contracts: raw_collection.try(:[], :cig_result).try(:[], :result).try(:[], :root).try(:[], :existing_contracts) || {},
            public_sources: raw_collection.try(:[], :cig_result).try(:[], :result).try(:[], :root).try(:[], :public_sources) || {},
            identification_documents: raw_collection.try(:[], :cig_result).try(:[], :result).try(:[], :root).try(:[], :identification_documents) || {},
            subject_details: raw_collection.try(:[], :cig_result).try(:[], :result).try(:[], :root).try(:[], :subject_details) || {},
            classification_of_borrower: raw_collection.try(:[], :cig_result).try(:[], :result).try(:[], :root).try(:[], :classification_of_borrower) || {},
            subjects_address: raw_collection.try(:[], :cig_result).try(:[], :result).try(:[], :root).try(:[], :subjects_address) || {},
            negative_data: raw_collection.try(:[], :cig_result).try(:[], :result).try(:[], :root).try(:[], :negative_data) || {},
            number_of_queries: raw_collection.try(:[], :cig_result).try(:[], :result).try(:[], :root).try(:[], :number_of_queries) || {},
            summary_information: raw_collection.try(:[], :cig_result).try(:[], :result).try(:[], :root).try(:[], :summary_information) || {}
          }
        elsif raw_collection.any? && raw_collection.try(:[], :cig_result_error).present?
          @data = {
            error_message: raw_collection.try(:[], :cig_result_error).try(:[], :errmessage) || {}
          }
        end
      end

      def report_exist?
        raw_collection.any? && raw_collection.try(:[], :cig_result).present? rescue false
      end

      def error_message?(message)
        data[:error_message].eql?(message) rescue false
      end

      def self.config_path
        %w[services pkb]
      end
    end
  end
end
