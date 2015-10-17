# All the little methods we use
# Probably should make a class here and clean up some

# Add msmc domains to all first.last
def build_aliases( name )
  Array( name ).map { |a| DOMAINS.map { |d| a + d } }.flatten.uniq
end

# Grab the primary address and the aliases from the proxyAddresses array
def build_exchange_entry( name, entry )
  internal_address = entry.proxyaddresses.find { |p| p =~ /^SMTP:/ }.sub( /^SMTP:/, '' ).downcase
  aliases = entry.proxyaddresses.find_all { |p| p =~ /^smtp:/ }.map { |p| p.sub( /^smtp:/, '' ).downcase }
  aliases = ( build_aliases( name ) + aliases + [internal_address] ).map { |a| a.gsub( /\s+/, '' ) }.uniq.sort
  return internal_address, aliases
end

# Build an entry for the master ldap
def add_entry( conn, name, entry )
  cn = construct_cn( name )
  parts = cn.split( ' ' )
  sn = ( parts.empty? ? '' : parts.last )
  gn = ( parts.length > 1 ? parts.first : '' )
  mail = construct_mail( name, entry[0] )
  attributes = {
    :displayName         => cn,
    :givenName           => gn,
    :sn                  => sn,
    :cn                  => cn,
    :mail                => mail,
    :mailHost            => entry[0],
    :mailAlias           => entry[2],
    :mailInternalAddress => entry[1],
    :objectClass         => [ 'mailRecipient', 'inetOrgPerson' ]
  }
  attributes.delete_if { |k,v| v.nil? or v.empty? }
  dn = construct_dn( cn )
  conn.add( :dn => dn, :attributes => attributes )
  conn.get_operation_result
end

# Update a master ldap entry
def update_entry( conn, name, entry )
  dn = construct_dn( construct_cn( name ) )
  ops = [
    [:replace, :mail,                construct_mail( name, entry[0] )],
    [:replace, :mailhost,            entry[0]],
    [:replace, :mailalias,           entry[2]],
    [:replace, :mailinternaladdress, entry[1]]
  ]
  end
  conn.modify( :dn => dn, :operations => ops )
  conn.get_operation_result
end

def construct_mail( name, mailhost )
  "#{name}@#{mailhost.sub(/^\w+\./, '' )}"
end

def construct_cn( name )
  name.split( '.' ).map { |n| n.capitalize }.join( ' ' ).gsub( /#/, '' )
end

def construct_dn( cn )
  "cn=#{cn},ou=Example,c=US"
end

def delete_entry( conn, name, entry )
  conn.delete( :dn => construct_dn( construct_cn( name ) ) )
  conn.get_operation_result
end

