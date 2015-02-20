class Provider < ActiveRecord::Base
	
	validates :endpoint_url, :presence => true, :format => { :with => /^https?/, :message => "must be an http/https url", :multiline => true}
	validates :email, :format => { :with => /@/, :message => "must be a valid email address"}, :allow_blank => true
	validates_length_of :new_provider_id_prefix, :maximum => 8
	scope :unique_by_contributing_institution, lambda { select(:contributing_institution).uniq}
	scope :unique_by_provider_id_prefix, lambda { select(:provider_id_prefix).uniq}

	before_save do
		self.name = nil if self.name.blank?
		self.set = nil if self.set.blank?
		self.metadata_prefix = nil if self.metadata_prefix.blank?
		self.contributing_institution = self.new_contributing_institution unless self.new_contributing_institution.blank?
		self.provider_id_prefix = self.new_provider_id_prefix unless self.new_provider_id_prefix.blank?
	end

	def client
		OAI::Client.new(self.endpoint_url, :parser => 'libxml')
	end

	def granularity
		client.identify.granularity
	end

	def each_record(options = {}, &block)
		response = nil
		count = 0
		begin
			local_options = {}
			local_options[:resumption_token] = response.resumption_token if response and response.resumption_token and not response.resumption_token.empty?
			local_options = oai_client_options if local_options.empty?
			response = client.list_records(local_options)
			response.doc.find("/OAI-PMH/ListRecords/record").each do |record|
			count += 1
			yield record
			break if options[:limit] and count >= options[:limit]
		end

		rescue
			raise unless $!.respond_to?(:code) and $!.try(:code) == "noRecordsMatch"
			end while (options[:limit].blank? or count < options[:limit]) and not response.try(:resumption_token).blank?
		end

		def consume!(options = {})
			count = 0
			each_record(options) do |xml|
			process_record(xml)
			count += 1
		end
		self.consumed_at = Time.now
		save
		count
	end

	def name
		read_attribute(:name) || endpoint_url
	end

	def email
		read_attribute(:email) || ''
	end

	def metadata_prefix
		read_attribute(:metadata_prefix) || 'oai_dc'
	end

	def contributing_institution
		read_attribute(:contributing_institution) || ''
	end

	def new_contributing_institution
		read_attribute(:new_contributing_institution) || ''
	end

	def collection_name
		read_attribute(:collection_name) || ''
	end

	def in_production
		read_attribute(:in_production) || ''
	end

	def provider_id_prefix
		read_attribute(:provider_id_prefix) || ''
	end

	def next_harvest_at
		consumed_at + interval
	end

	def consumed_at
		read_attribute(:consumed_at) || Time.at(1)
	end

	def interval
		(read_attribute(:interval) || 1.day).seconds
	end
	
	protected
	
		def oai_client_options
			options = {}
			options[:set] = set unless set.blank?
			options[:from] = consumed_at.utc.xmlschema.to_s.slice(0,granularity.length) unless consumed_at.blank?
			options[:metadata_prefix] = metadata_prefix
			options
		end

		def process_record xml
			record = record_class.from_xml xml.to_s
			record.provider = self
			record.update_index
			record
		end

end
