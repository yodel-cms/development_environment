class SitesPageModelMigration < Migration
  def self.up(site)
    site.pages.create_model :sites_page do |sites_pages|
      sites_pages.record_class_name = 'SitesPage'
    end
  end
  
  def self.down(site)
    site.sites_pages.destroy
  end
end
