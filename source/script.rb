require "json"

def get_tableplus_backup_path
  # Read the backup path from TablePlus preferences
  # The SharedConnectionPath is nested in the preferences, so we need to parse it
  prefs_output = `defaults read com.tinyapp.TablePlus 2>/dev/null`
  return nil if prefs_output.empty?
  
  # Extract the SharedConnectionPath value using regex
  match = prefs_output.match(/SharedConnectionPath\s*=\s*"([^"]+)"/)
  return nil unless match
  
  backup_path = match[1]
  return nil if backup_path.empty? || backup_path == "(null)"
  
  # Construct the full path to Connections.plist in the backup directory
  File.join(backup_path, "Connections.plist")
end

def main
  # Get the backup path from TablePlus config
  backup_connections_file = get_tableplus_backup_path
  
  possible_files = [
    File.expand_path("~/Library/Application Support/com.tinyapp.TablePlus/Data/Connections.plist"),
    File.expand_path("~/Library/Application Support/com.tinyapp.TablePlus-setapp/Data/Connections.plist"),
  ]
  
  # Add backup location if it exists and is different from default locations
  if backup_connections_file && File.file?(backup_connections_file)
    possible_files << backup_connections_file
  end

  # Find all existing files and their modification times
  existing_files = possible_files.select { |filepath| File.file?(filepath) }
  
  if existing_files.empty?
    error_message = {
      title: "Could not fetch connections",
      valid: false,
    }
    puts JSON.dump({items: [error_message]})
    return
  end

  # Use the most recently modified file
  connections_file = existing_files.max_by { |filepath| File.mtime(filepath) }

  if connections_file.nil?
    error_message = {
      title: "Could not fetch connections",
      valid: false,
    }
    puts JSON.dump({items: [error_message]})
    return
  end

  output = parse_plist(connections_file).map do |connection|
    id = connection.fetch("ID")
    name = connection.fetch("ConnectionName")
    db_name = connection.fetch("DatabaseName")
    env = connection.fetch("Enviroment")
    {
      uid: id,
      title: name,
      subtitle: "[#{env}] #{db_name}",
      match: "#{name} #{env} #{db_name}",
      arg: "tableplus://?id=#{id}"
    }
  end
  puts JSON.dump({items: output})
end

def parse_plist(filepath)
  # Use a simpler approach with backticks instead of pipes
  json_output = `plutil -convert json -o - "#{filepath}"`
  JSON.parse(json_output)
end

main
