class DevelopmentSitesPage < RecordProxyPage
  REMOTE_NAME = 'yodel'
  
  # record proxy pages deal with site models (site.model_name). Override the methods it uses
  # to interact with these models we can edit Sites (a non site model)
  def record
    @record ||= Site.find(BSON::ObjectId.from_string(params['id']))
  end
  
  def records
    @records ||= Site.all
  end

  # a default user is required before any sites or remotes can be created
  respond_to :get do
    with :html do
      if site.default_users.count == 0
        response.redirect '/setup'
      else
        super()
      end
    end
  end

  # create a site
  respond_to :post do
    # clone a site from a remote server
    with :json do
      # ensure yodel is set up
      default_user = site.default_users.first
      return {success: false, reason: 'No default user has been created'} if site.default_users.count == 0
      
      # extract the site name and generate an identifier to be used as the site's domain and folder name
      site_name = params['name'].to_s
      identifier = site_name.downcase.gsub(/[^a-z0-9]+/, '_')
      return {success: false, reason: 'No site name provided'} if site_name.blank? || identifier.blank?
      
      # find the remote to clone from
      remote = Remote.find(BSON::ObjectId.from_string(params['remote']))
      return {success: false, reason: 'Remote could not be found'} if remote.nil?
      
      # construct the git url used to clone the site
      remote_id = params['remote_id']
      git_url = remote.git_url(remote_id)
      return {success: false, reason: 'Git URL could not be constructed'} if git_url.blank?
      
      # find an unused site folder name
      site_folder = identifier
      counter = 0
      while File.exist?(File.join(Yodel.config.sites_root, site_folder))
        counter += 1
        site_folder = "#{identifier}_#{counter}"
      end
      
      # clone the repos locally  
      Dir.chdir(Yodel.config.sites_root) do
        result = `#{Yodel.config.git_path} clone -o #{REMOTE_NAME} #{git_url} #{site_folder}`
        return {success: false, reason: 'Git error: ' + $1} if result =~ /error: (.+)$/
      end
      
      # when running as a daemon, the root user will own the cloned repos
      Dir.chdir(Yodel.config.sites_root) do
        return unless Yodel.config.owner_user
        if Yodel.config.owner_group != 0
          FileUtils.chown_R(Yodel.config.owner_user, Yodel.config.owner_group, site_folder)
        else
          FileUtils.chown_R(Yodel.config.owner_user, nil, site_folder)
        end
      end
      
      # create a new site from the cloned site.yml file
      site_yml = File.join(Yodel.config.sites_root, site_folder, Yodel::SITE_YML_FILE_NAME)
      return {success: false, reason: 'Site yml file was not cloned successfully'} unless File.exist?(site_yml)
      new_site = Site.load_from_site_yaml(site_yml)
      
      # find an unused default local domain
      domain_identifier = identifier.gsub('_', '')
      domain = "#{domain_identifier}.yodel"
      counter = 0
      while Site.exists?(domains: domain)
        counter += 1
        domain = "#{domain_identifier}-#{counter}.yodel"
      end
      
      # add the remote and a new default local domain
      new_site.domains.unshift(domain)
      new_site.remote_id = remote_id
      new_site.remote = remote
      new_site.save
      
      # initialise the site
      Migration.run_migrations(new_site)
      create_default_user(new_site, default_user)
      {success: true, url: new_site_url(new_site)}
    end
    
    # create a new local site
    with :html do
      # the default user is required for the git repos, and creating an
      # admin account in the new site
      default_user = site.default_users.first
      if default_user.nil?
        response.redirect '/setup'
        return
      end
      
      name = cleanse_name(params['name'].sub('.yodel', ''))
      if name.blank?
        flash[:error] = 'You must enter a name for this site'
        response.redirect '/sites'
        return
      end
      
      # create a new folder for the site
      site_dir = File.join(Yodel.config.sites_root, name)
      FileUtils.cp_r(File.join(File.dirname(__FILE__), '..', 'site_template'), site_dir)
      
      # rename the gitignore file so it becomes active
      FileUtils.mv(File.join(site_dir, 'gitignore'), File.join(site_dir, '.gitignore'))

      # create the new site
      new_site = Site.new
      new_site.name = name
      new_site.root_directory = site_dir
      new_site.domains << "#{name}.yodel"

      # copy core yodel migrations
      yodel_migrations_dir = File.join(site_dir, Yodel::MIGRATIONS_DIRECTORY_NAME, Yodel::YODEL_MIGRATIONS_DIRECTORY_NAME)
      FileUtils.cp_r(Yodel.config.yodel_migration_directory, yodel_migrations_dir)

      # copy extension migrations
      extension_migrations_dir = File.join(site_dir, Yodel::MIGRATIONS_DIRECTORY_NAME, Yodel::EXTENSION_MIGRATIONS_DIRECTORY_NAME)
      Yodel.config.extensions.each do |extension|
        FileUtils.cp_r(extension.migrations_dir, File.join(extension_migrations_dir, extension.name)) if File.directory?(extension.migrations_dir)
        new_site.extensions << extension.name
      end

      # create the repository and perform the first commit
      if Yodel.config.owner_user
        if Yodel.config.owner_group != 0
          FileUtils.chown_R(Yodel.config.owner_user, Yodel.config.owner_group, site_dir)
        else
          FileUtils.chown_R(Yodel.config.owner_user, nil, site_dir)
        end
      end
      repos = Git.init(site_dir)
      repos.config('user.name', default_user.name)
      repos.config('user.email', default_user.email)
      repos.config('http.postBuffer', (200 * 1024 * 1024))
      repos.add([Yodel::LAYOUTS_DIRECTORY_NAME, Yodel::MIGRATIONS_DIRECTORY_NAME, Yodel::PARTIALS_DIRECTORY_NAME, Yodel::PUBLIC_DIRECTORY_NAME, Yodel::ATTACHMENTS_DIRECTORY_NAME])
      repos.commit_all('New yodel site')

      # save and initialise the site
      new_site.save
      Migration.run_migrations(new_site)
      create_default_user(new_site, default_user)

      # redirect to the new site
      response.redirect new_site_url(new_site)
    end
  end
  
  private
    def cleanse_name(name)
      name.downcase.gsub(/[^a-z0-9]+/, '_')
    end
    
    def create_default_user(new_site, default_user)
      user = new_site.users.new
      user.first_name = default_user.name
      user.email = default_user.email
      user.username = default_user.email
      user.password = Password.hashed_password(nil, default_user.password)
      user.groups << new_site.groups['Developers']
      user.save
      
      # because of the before_create callback, we need to override
      # the salt and password manually by saving again
      user.password_salt = nil
      user.password = Password.hashed_password(nil, default_user.password)
      user.save_without_validation
    end
    
    def new_site_url(new_site)
      port = (request.port == 80 ? nil : request.port)
      "http://#{new_site.domains.first}#{':' if port}#{port}/admin/pages"
    end
end
