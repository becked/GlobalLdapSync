# ldap server configurations
# TODO: Ideally this would be YAML

class LdapConfig
  def self.master
  {
    :host => 'ldap.example.edu',
    :base => 'c=US',
    :authentication => {
      :method   => :simple,
      :username => 'cn=Admin,c=US',
      :password => 'password'
    },
    :attributes => [ 'mail', 'mailinternaladdress', 'mailalias', 'mailhost' ],
    :filter     => 'objectClass=mailRecipient'
  }
  end
  
  def self.exchange
  {
    :host => 'exchange.example.edu',
    :base => 'dc=example,dc=edu',
    :authentication => {
      :method   => :simple,
      :username => 'cn=admin-user,cn=users,dc=example,dc=edu',
      :password => 'password'
    },
    :attributes => [ 'mail', 'proxyaddresses' ],
    :filter     => '(&(!(userAccountControl=514))(!(userAccountControl=66050))(!(msExchHideFromAddressLists=TRUE))(!(cn=SystemMailbox*))(&(mailnickname=*)(|(&(objectCategory=person)(objectClass=user)(|(homeMDB=*)(msExchHomeServerName=*)))(objectCategory=group)(objectCategory=publicFolder)(objectCategory=msExchDynamicDistributionList))))'
  }
  end
 
end
