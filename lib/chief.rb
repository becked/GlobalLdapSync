require 'rubygems'
require 'dbi'
require 'pg'

class Chief

  DATABASE_INFO = {
    :user       => 'user',
    :password   => 'pass',
    :db         => 'DBI:Pg:chief:db.example.edu'
  } unless defined?( DATABASE_INFO )

  def db_connect
    dbi = DBI.connect( DATABASE_INFO[:db], DATABASE_INFO[:user], DATABASE_INFO[:password] )
    if block_given?
      begin
        yield dbi
      ensure
        dbi.disconnect if dbi.connected?
      end
    else
      return dbi
    end
  end

  def aliases
    aliases = Hash.new
    sql =<<EOF
SELECT
    LOWER( mail_addresses.address ) AS address,
    LOWER( mail_aliases.alias ) AS alias
  FROM
    mail_aliases, mail_addresses
  WHERE
    mail_addresses.id = mail_aliases.mail_address_id AND
    SPLIT_PART( address, '@', 1 ) <> alias
EOF
    db_connect do |db|
      db.select_all( sql ).each do |row|
        name = row['address'].split(/@/).first
        if aliases.has_key? name
          aliases[name] << row['alias']
        else
          aliases[name] = [ row['alias'] ]
        end
      end
    end
    aliases
  end

  def mailman_aliases
    aliases = Hash.new
    sql =<<EOF
SELECT
    LOWER( mail_aliases.alias     ) AS alias,
    LOWER( mail_addresses.address ) AS address
  FROM
    mail_aliases, mail_addresses
  WHERE
    mail_addresses.id = mail_aliases.mail_address_id AND
    (
      mail_aliases.id in ( SELECT              mail_alias_id  FROM mailing_lists ) OR
      mail_aliases.id in ( SELECT         join_mail_alias_id  FROM mailing_lists ) OR
      mail_aliases.id in ( SELECT        admin_mail_alias_id  FROM mailing_lists ) OR
      mail_aliases.id in ( SELECT        leave_mail_alias_id  FROM mailing_lists ) OR
      mail_aliases.id in ( SELECT        owner_mail_alias_id  FROM mailing_lists ) OR
      mail_aliases.id in ( SELECT      request_mail_alias_id  FROM mailing_lists ) OR
      mail_aliases.id in ( SELECT      bounces_mail_alias_id  FROM mailing_lists ) OR
      mail_aliases.id in ( SELECT      confirm_mail_alias_id  FROM mailing_lists ) OR
      mail_aliases.id in ( SELECT    subscribe_mail_alias_id  FROM mailing_lists ) OR
      mail_aliases.id in ( SELECT  unsubscribe_mail_alias_id  FROM mailing_lists )
    )
EOF
    db_connect do |db| 
      db.select_all( sql ).each do |row|
        name = row['address'].split(/@/).first
        if aliases.has_key? name
          aliases[name] << row['alias']
        else
          aliases[name] = [ row['alias'] ]
        end
      end
    end
    aliases
  end

end
