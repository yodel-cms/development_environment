class DefaultUserModelMigration < Migration
  def self.up(site)
    site.records.create_model :default_user do |default_users|
      add_field :name, :string, validations: {required: {}}
      add_field :email, :email, validations: {required: {}}
      add_field :password, :password, validations: {required: {}}
    end
  end
  
  def self.down(site)
    site.default_users.destroy
  end
end
