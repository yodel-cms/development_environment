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
    sites.show_record_layout = 'site'
    sites.save
    
    # remotes
    remotes = site.remotes_pages.new
    remotes.title = 'Remotes'
    remotes.parent = home
    remotes.show_record_layout = 'remote'
    remotes.save
    
    # default user
    default_user = site.record_proxy_pages.new
    default_user.title = 'Default User'
    default_user.parent = home
    default_user.record_model = site.default_users
    default_user.page_layout = 'default_user'
    default_user.after_update_page = default_user
    default_user.save
    
    # second setup step (done first because the first step refns this)
    setup_two = site.pages.new
    setup_two.title = 'Setup Remote'
    setup_two.parent = home
    setup_two.page_layout = 'setup_remote'
    setup_two.save
    
    # initial setup
    setup = site.pages.new
    setup.title = 'Setup'
    setup.parent = home
    setup.page_layout = 'setup'
    setup.save
    
    # menu
    nav = site.menus.new
    nav.name = 'nav'
    nav.root = home
    s1 = nav.exceptions.new
    s1.page = setup
    s1.show = false
    s1.save
    s2 = nav.exceptions.new
    s2.page = setup_two
    s2.show = false
    s2.save
    nav.save
  end
  
  def self.down(site)
    site.pages.all.each(&:destroy)
  end
end
