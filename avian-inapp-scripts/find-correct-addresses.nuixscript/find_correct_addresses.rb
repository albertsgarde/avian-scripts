require 'set'

# Standard code for finding main directory.
script_directory = File.dirname(__FILE__)
require File.join(script_directory,"..","setup.nuixscript","get_main_directory")

main_directory = get_main_directory(false)

unless main_directory
    puts("Script cancelled.")
    return
end

# For GUI messages.
require File.join(main_directory,"utils","nx_utils")
require File.join(main_directory,"utils","union_find")
# For storing result.
require File.join(main_directory,"utils","settings_utils")
require File.join(main_directory,"utils","identifier_graph")

# Returns a list of all the addresses in the communication of the item if such exists.
def all_addresses_in_item(item)
    communication = item.communication
    result = Set[]
    if communication
        if communication.from
            result.merge(communication.from)
        end
        if communication.to
            result.merge(communication.to)
        end
        if communication.cc
            result.merge(communication.cc)
        end
        if communication.bcc
            result.merge(communication.bcc)
        end
    end
    return result
end

puts("Running script...")

# The output directory.
output_dir = SettingsUtils::case_data_dir(main_directory, current_case)

# Find all items with a communication.
messages = current_case.search("has-communication:1")

puts("Found " + messages.length.to_s + " items with communication.")

identifier_graph = IdentifierGraph::IdentifierGraph.new

# Add all addresses to the graph.
for message in messages
    for address in all_addresses_in_item(message)
        identifier_graph.add_address(address)
    end
end

graph_file_path = File.join(output_dir, "find_correct_addresses_graph.csv")
CSV.open(graph_file_path, "wb") do |csv|
    identifier_graph.to_csv(csv)
end

identifiers = identifier_graph.to_union_find

puts("Found " + identifiers.num_components.to_s + " unique persons.")

puts("Writing output to file...")
# Write results to file.
output_file_path = File.join(output_dir,"find_correct_addresses_output.txt")
file = File.open(output_file_path, 'w')
file.puts(identifiers.to_s)
file.close

# Inform user of finished script.
CommonDialogs.show_information("Script finished. Found " + identifiers.num_components.to_s + " unique persons. \nThe result has been stored and is ready for use by other scripts.", "Find Correct Addresses")

puts("Script finished.")
