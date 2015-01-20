require "active-fedora"
require "open-uri"
require "fileutils"
require "oai"

module HarvestUtils

  private
  
  config = YAML.load_file(File.expand_path("#{Rails.root}/config/dpla.yml", __FILE__))
  @harvest_path = config['harvest_data_directory'] 
  @converted_path = config['converted_foxml_directory']
  @pid_prefix = config['pid_prefix'] 
  @partner = config['partner'] 

  def harvest_action(provider)

    #make sure there are no excess harvest or conversion fixture files before restarting the tasks
    FileUtils.rm_rf(Dir.glob('#{@harvest_path}/*'))
    FileUtils.rm_rf(Dir.glob('#{@converted_path}/*'))
    
    harvest(provider)
    convert()
    rec_count = ingest()
    rec_count
  end
  module_function :harvest_action

  def harvest(provider)
    full_records = ''
    client = OAI::Client.new provider.endpoint_url
    response = client.list_records
    set = provider.set if provider.set
    response = client.list_records :set => set if set
    response.each do |record|
      puts record.metadata
      full_records += record.metadata.to_s
    end
    while(response.resumption_token and not response.resumption_token.empty?)
      token = response.resumption_token
      response = client.list_records :resumption_token => token if token
      response.each do |record|
        puts record.metadata
        full_records += record.metadata.to_s
      end
    end
    f_name = provider.name.gsub(/\s+/, "") +  (set ? set : "") + "_" + Time.now.to_i.to_s + ".xml"
    f_name_full = Rails.root + @harvest_path + f_name
    FileUtils::mkdir_p @harvest_path
    File.open(f_name_full, "w") { |file| file.puts full_records }
    add_xml_formatting(f_name_full, :contributing_institution => provider.contributing_institution, :set_spec => provider.set, :collection_name => provider.collection_name)
  end
  module_function :harvest 

  def convert()

      xslt_path = Rails.root.join("lib", "tasks", "oai_to_foxml.xsl")
      u_files = Dir.glob("#{@harvest_path}/*").select { |fn| File.file?(fn) }
      puts "#{u_files.length} #{"provider".pluralize(u_files.length)} detected"
      u_files.length.times do |i|
        puts "Contents of #{u_files[i]} transformed"
        `xsltproc #{Rails.root}/lib/tasks/oai_to_foxml.xsl #{u_files[i]}`
        File.delete(u_files[i])
      end
  end
  module_function :convert

  def ingest()
    contents = @converted_path ? Dir.glob(File.join(@converted_path, "*.xml")) : Dir.glob("spec/fixtures/fedora/*.xml")
    contents.each do |file|
      puts file
      pid = ActiveFedora::FixtureLoader.import_to_fedora(file)
      ActiveFedora::FixtureLoader.index(pid)
      obj = OaiRec.find(pid)
      obj.to_solr
      obj.update_index
      File.delete(file)
    end
    contents.size
  end
  module_function :ingest

  def cleanout_and_reindex(provider)
    rec_count = 0
    ActiveFedora::Base.find_each({'contributing_institution_si'=>provider.contributing_institution}, batch_size: 2000) do |o|
      delete_from_aggregator(o)
      rec_count += 1
    end
    rec_count
  end
  module_function :cleanout_and_reindex

  def delete_all
    ActiveFedora::Base.find_each({},batch_size: 2000) do |o|
      delete_from_aggregator(o)
    end
  end
  module_function :delete_all

  def self.delete_from_aggregator(o)
    o.delete if o.pid.starts_with?(@pid_prefix + ':')
  end

  def self.add_xml_formatting(xml_file, options = {})
      contributing_institution = options[:contributing_institution] || ''
      set_spec = options[:set_spec] || ''
      collection_name = options[:collection_name] || ''
      new_file = "/tmp/xml_hold_file.xml"
      xml_heading = '<?xml version="1.0" encoding="UTF-8"?>'
      unless File.open(xml_file).each_line.any?{|line| line.include?(xml_heading)}
        fopen = File.open(xml_file)
        xml_file_contents = fopen.read
        xml_open = "<records>"
        xml_close = "</records>"
        xml_manifest = get_xml_manifest(contributing_institution, set_spec, collection_name)
        fopen.close
        File.open(new_file, 'w') do |f|  
          f.puts xml_heading
          f.puts xml_open
          f.puts xml_manifest
          f.puts xml_file_contents
          f.puts xml_close
          File.rename(new_file, xml_file)
          f.close
        end
      end

    end

    def self.get_xml_manifest(contributing_institution, set_spec, collection_name)
      harvest_s = @harvest_path.to_s
      converted_s = @converted_path.to_s
      partner_s = @partner.to_s
      xml_manifest = "<manifest><partner>#{partner_s}</partner><contributing_institution>#{contributing_institution}</contributing_institution><set_spec>#{set_spec}</set_spec><collection_name>#{collection_name}</collection_name><harvest_data_directory>#{harvest_s}</harvest_data_directory><converted_foxml_directory>#{converted_s}</converted_foxml_directory></manifest>"
      return xml_manifest
    end
end



