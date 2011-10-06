class RemoteModelMigration < Migration
  def self.up(site)
    site.pages.create :remote do |remotes|
      add_field :url, :string, validations: {required: {}}
      add_field :username, :string, validations: {required: {}}
      add_field :password, :string, validations: {required: {}}
      remotes.record_class_name = 'Remote'
    end
  end
  
  def self.down(site)
    site.remotes.destroy
  end
end
