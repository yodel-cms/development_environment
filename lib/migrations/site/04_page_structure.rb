class PageStructureMigration < Migration
  def self.up(site)
    # remove the default home page
    home = site.pages.where(path: '/').first
    home.destroy
    
    # home redirects to sites
    home = site.redirect_pages.new
    home.title = 'Home'
    home.url = '/sites'
    home.save
    
    # sites
    sites = site.sites_pages.new
    sites.title = 'Sites'
    sites.parent = home
    sites.save
    
    # remotes
    remotes = site.remotes_pages.new
    remotes.title = 'Remotes'
    remotes.parent = home
    remotes.save
    
    # second setup step (done first because the first step refns this)
    setup_two = site.record_proxy_pages.new
    setup_two.title = 'Setup Remote'
    setup_two.parent = home
    setup_two.record_model = Remote
    setup_two.after_create_page = sites
    setup_two.page_layout = 'setup_remote'
    setup_two.save
    
    # initial setup
    setup = site.record_proxy_pages.new
    setup.title = 'Setup'
    setup.parent = home
    setup.record_model = site.default_users
    setup.after_create_page = setup_two
    setup.page_layout = 'setup'
    setup.save
  end
  
  def self.down(site)
    site.pages.all.each(&:destroy)
  end
end
