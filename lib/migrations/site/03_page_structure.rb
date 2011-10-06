class PageStructureMigration < Migration
  def self.up(site)
    # remove the default home page
    home = site.pages.where(path: '/').first
    home.destroy
    
    # home redirects to sites
    home = site.redirect_pages.new
    home.title = "Home"
    home.url = '/sites'
    home.save
    
    # sites
    sites = site.sites_pages.new
    sites.title = "Sites"
    sites.parent = home
    sites.save
    
    # remotes
    remotes = site.pages.new
    remotes.title = "Remotes"
    remotes.parent = home
    remotes.default_child_model = site.remotes
    remotes.page_layout = 'remotes'
    remotes.save
  end
  
  def self.down(site)
    site.pages.all.each(&:destroy)
  end
end
