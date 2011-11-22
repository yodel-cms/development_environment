class DevelopmentSitesPage < RecordProxyPage
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
    with :html do
      if site.default_users.count == 0
        response.redirect '/setup'
        return
      end
      
      name = params['name'].sub('.yodel', '')
      if name.blank?
        flash[:error] = 'You must enter a name for this site'
        response.redirect '/sites'
        return
      end
      
      # the default user is required for the git repos, and creating an
      # admin account in the new site
      default_user = site.default_users.first
      
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
      repos.add([Yodel::LAYOUTS_DIRECTORY_NAME, Yodel::MIGRATIONS_DIRECTORY_NAME, Yodel::PARTIALS_DIRECTORY_NAME, Yodel::PUBLIC_DIRECTORY_NAME, Yodel::ATTACHMENTS_DIRECTORY_NAME])
      repos.commit_all('New yodel site')

      # save and initialise the site
      new_site.save
      Migration.run_migrations(new_site)

      # create a default admin user
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

      # redirect to the new site
      port = (request.port == 80 ? nil : request.port)
      response.redirect "http://#{new_site.domains.first}#{':' if port}#{port}/admin/pages"
    end
  end  
end
