script_directory = File.dirname(__FILE__)
require File.join(script_directory,'..','..','setup.nuixscript','get_main_directory')

main_directory = get_main_directory(false)

unless main_directory
    puts('Script cancelled because no main directory could be found.')
    return
end

require File.join(main_directory, 'utils', 'utils')

require File.join(main_directory, 'utils', 'settings_utils')

require File.join(main_directory, 'utils', 'custom_communication')

require File.join(main_directory, 'utils', 'dates')

require File.join(main_directory, 'avian-inapp-scripts', 'unidentified-emails', 'find-unidentified-emails.nuixscript', 'find_unidentified_emails')


module FixUnidentifiedEmails
    extend self
    class CommunicationFieldAliases
        attr_reader :from, :to, :cc, :bcc, :subject, :date

        def initialize(from_aliases, to_aliases, cc_aliases, bcc_aliases, subject_aliases, date_aliases)
            @from = from_aliases
            @to = to_aliases
            @cc = cc_aliases
            @bcc = bcc_aliases
            @subject = subject_aliases
            @date = date_aliases
            
            unless Utils::sets_disjoint?(@from, @to, @cc, @bcc, @subject, @date) 
                raise ArgumentError, 'All sets of aliases must be disjoint.'
            end
        end

        def to_hash
            { :from => @from, :to => @to, :cc => @cc, :bcc => @bcc, :subject => @subject, :date => @date }
        end
    end
        

    # Return a hash of possible fields and there values.
    def find_fields(text, communication_field_aliases)
        lines = text.lines.map { |line| line.strip }
        
        fields = {}

        for field_key, aliases in communication_field_aliases
            contained_aliases = aliases.select { |field_alias| lines.any? { |line| line.start_with?(field_alias) } }
            if contained_aliases.size > 1
                raise "Text contains multiple aliases for field '#{field_key}'."
            elsif contained_aliases.size == 1
                fields[field_key] = lines.find { |line| line.start_with?(contained_aliases[0]) }[contained_aliases[0].size..-1].strip
            else
                fields[field_key] = ''
            end
        end
        return fields
    end

    # Given a string representing a list of addresses, returns the list of addresses as CustomAddresses.
    # address_regexps should be a ordered list of regexps that match the different address formats. 
    #   Capture group 1 is the personal address and capture group 2 is the address address.
    # The address_splitter should split the string into a list of strings representing individual addresses.
    def identify_addresses(field_text, address_regexps, &address_splitter)
        if field_text == ''
            return []
        end
        address_strings = address_splitter.call(field_text)
        return address_strings.map do |address_string|
            if regexp = address_regexps.find{ |regexp| address_string.match(regexp) }
                personal, address = address_string.match(regexp).captures
                Custom::CustomAddress.new(personal, address)
            else
                raise 'No regexp matches address string'
            end
        end
    end

    def parse_date(date_string)
        if date_string == ''
            return nil
        end
        english_date_string = Dates::danish_date_string_to_english(date_string)
        ruby_date_time = RubyDateTime.parse(english_date_string)
        joda_time = Dates::date_time_to_joda_time(ruby_date_time)
        return joda_time
    end

    # The body of the FixUnidentifiedEmails script.
    # Finds the communication fields, adds them as custom metadata and exports them to a file by item guid.
    # Params:
    # +data_path+:: The path string to the case's data directory.
    # +current_case+:: The current case.
    # +items+:: The items on which to run the script.
    # +progress_dialog+:: The progress_dialog to update with script progress.
    # +timer+:: The timer to record internal timings in.
    # +communication_field_aliases+:: Lists of aliases for each of the communication fields. In text, a ':' will be added to the end of each.
    # +start_area_size+:: Number of characters at the start of each items text to search for field information.
    # +address_regexps+:: Regexps for possible address formats. First capture group should be the personal part and second is the address part.
    # +address_splitter+:: A block that takes a string and splits it into individual address strings that are then matched to the above regexps.
    def fix_unidentified_emails(data_path, current_case, items, progress_dialog, timer, communication_field_aliases, start_area_size, address_regexps, &address_splitter)
        progress_dialog.set_main_status_and_log_it('Finding communication fields for items...')
        item_communications = {}
        timer.start('find_communication_fields')
        for item in items
            # Find the text for each of the communication fields.
            timer.start('find_field_text')
            fields = find_fields(FindUnidentifiedEmails::metadata_text(item, start_area_size, timer), communication_field_aliases)
            timer.stop('find_field_text')

            # Extract information about the addresses from the from, to, cc, and bcc field strings.
            timer.start('identify_addresses')
            from_addresses = identify_addresses(fields[:from], address_regexps, &address_splitter)
            to_addresses = identify_addresses(fields[:to], address_regexps, &address_splitter)
            cc_addresses = identify_addresses(fields[:cc], address_regexps, &address_splitter)
            bcc_addresses = identify_addresses(fields[:bcc], address_regexps, &address_splitter)
            timer.stop('identify_addresses')

            # Find date.
            timer.start('find_date')
            date = parse_date(fields[:date])
            timer.stop('find_date')

            # Find subject.
            subject = fields[:subject]
            
            # Create communication and add to hash
            communication = Custom::CustomCommunication.new(date, subject, from_addresses, to_addresses, cc_addresses, bcc_addresses)
            puts("rødspætte: " + communication.to_s)
            item_communications[item.guid] = communication

            # Add custom metadata. Should be removed later.
            address_to_string = lambda do |address|
                "<#{address.personal}, #{address.address}>"
            end
            item.custom_metadata['FromAddresses'] = from_addresses.map(&address_to_string).to_s
            item.custom_metadata['ToAddresses'] = to_addresses.map(&address_to_string).to_s
            item.custom_metadata['CcAddresses'] = cc_addresses.map(&address_to_string).to_s
            item.custom_metadata['BccAddresses'] = bcc_addresses.map(&address_to_string).to_s
        end
        timer.stop('find_communication_fields')

        # Save communications to file.
        timer.start('save_communications')
        timer.start('create_yaml_hash')
        puts("pighvar: " + item_communications.to_s)
        puts("stenbidder: " + item_communications.map{ |guid, communication| [guid, communication.to_yaml_hash] }.to_s)
        yaml_hash = Hash[item_communications.map{ |guid, communication| [guid, communication.to_yaml_hash] }]
        puts("sild: " + yaml_hash.to_yaml)
        timer.stop('create_yaml_hash')
        File.open(data_path, 'w') { |file| file.write(yaml_hash.to_yaml) }
        timer.stop('save_communications')
    end
end