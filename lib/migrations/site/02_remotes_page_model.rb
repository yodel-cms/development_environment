class RemoteModelMigration < Migration
  def self.up(site)
    site.record_proxy_pages.create_model :remotes_page do |remotes_pages|
      remotes_pages.record_class_name = 'RemotesPage'
    end
  end
  
  def self.down(site)
    sites.remotes_pages.destroy
  end
end
