#!/usr/local/bin/ruby

GLOBAL_LDAP_ROOT = "/data/sync"
LOCK_FILE = "#{GLOBAL_LDAP_ROOT}/run/lock.file"
UPDATE_THRESHOLD = 100
DELETE_THRESHOLD = 100

# Add our lib directory to the load path
$: << "#{GLOBAL_LDAP_ROOT}/lib"
require "mail"

begin 
  # Check/create lockfile 
  if File.exists?(LOCK_FILE)
    puts "Lockfile exists, exiting." 
    mail_on_lock
    exit!
  end 
  system "/usr/bin/touch #{LOCK_FILE}"

  require "chief"
  require "rubygems"
  require "net/ldap"
  require "ldap_logger"
  require "ldap_config"
  require "ldap_methods"

  # Everyone gets these domains added to their first.last
  DOMAINS = ["@example.com", "@example.org", "@example.net"]

  logger = LdapLogger.new
  logger.info "Start synchronization"


  ##################################################################
  # Build entry hashes of all our mail addresses
  # Format: { mail_address => [ mailHost, mailInternalAddress, [ array_of_aliases ] ] }

  entries = Hash.new
  master_entries = Hash.new

  # Master
  logger.info "Load master"
  master_conn = Net::LDAP.new(
    :host => LdapConfig.master[:host],
    :base => LdapConfig.master[:base],
    :auth => LdapConfig.master[:authentication]
  )
  master_conn.search(:filter => LdapConfig.master[:filter], :attributes => LdapConfig.master[:attributes]) do |e|
    name = e.mail.first.downcase.split(/@/).first
    master_entries[name] = [e.mailhost.first, e.mailinternaladdress.first, e.mailalias]
  end
  logger.info "Master loaded: #{master_entries.length} entries"

  # Chief Mailman
  logger.info "Load Chief Mailman"
  chief_mailman_count = 0
  Chief.new.mailman_aliases.each do |name,aliases|
    aliases = aliases.map { |a| (DOMAINS + ["@mailman.example.edu"]).map { |d| a + d } }.flatten.uniq
    entries[name] = ["mailman.example.edu", "#{name}@mailman.examplemedu", aliases]
    chief_mailman_count += 1
  end
  logger.info "Chief Mailman loaded: #{chief_mailman_count}"

  # Exchange
  logger.info "Load exchange"
  exchange_count = 0
  Net::LDAP.new(
    :host => LdapConfig.exchange[:host],
    :base => LdapConfig.exchange[:base],
    :auth => LdapConfig.exchange[:authentication]
  ).search(:filter => LdapConfig.exchange[:filter], :attributes => LdapConfig.exchange[:attributes]) do |e|
    begin
      name = e.mail.first.downcase.split(/@/).first
      entries[name] = ["exchange.example.edu", *(build_exchange_entry(name, e))]
    rescue => e
      exchange_count += 1
      logger.error "ERROR | #{e} | #{e.inspect}"
    end
  end
  logger.info "Exchange loaded: #{exchange_count}"

  ##################################################################
  # Add or update master

  logger.info "Update master"
  additions = {}
  updates = {}
  deletes = {}

  entries.each_pair do |name,entry|
    if not master_entries.has_key?(name)
      additions[name] = entry
    elsif entry != master_entries[name]
      updates[name] = entry
    end
  end

  master_entries.each_pair do |name,entry|
    deletes[name] = entry unless entries.has_key?(name)
  end

  logger.info "Adding to master"
  additions.each_pair do |name,entry|
    result = add_entry(master_conn, name, entry)
    logger.info "ADD | #{name} | #{entry.inspect} | #{result.inspect}"
  end
  logger.info "Adding #{additions.length} to master"

  logger.info "Updates to master"
  if updates.length > UPDATE_THRESHOLD
    logger.error "Update threshold reached, aborting: #{updates.length}"
    mail_on_updates(updates)
  else
    updates.each_pair do |name,entry|
      result = update_entry(master_conn, name, entry)
      logger.info "UPD | #{name} | #{entry.inspect} | #{result.inspect}"
    end
  end
  logger.info "Updated #{updates.length} to master"

  logger.info "Deletes to master"
  if deletes.length > DELETE_THRESHOLD
    logger.error "Delete threshold reached, aborting: #{deletes.length}"
    mail_on_deletes(deletes)
  else
    deletes.each_pair do |name,entry|
      result = delete_entry(master_conn, name, entry)
      logger.info "DEL | #{name} | #{entry.inspect} | #{result.inspect}"
    end
  end
  logger.info "Deleted #{deletes.length} to master"

  logger.info "Master updated"
  logger.info "End synchronization"

ensure
  # Remove lockfile
  File.delete(LOCK_FILE)
end

