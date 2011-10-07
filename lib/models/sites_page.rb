class SitesPage < Page
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
      name = params['name']
      if name.blank?
        flash[:error] = 'You must enter a name for this site'
        response.redirect '/sites'
        return
      end
      
      # create a new folder for the site
      site_dir = File.join(Yodel.config.sites_root, name)
      FileUtils.mkdir(site_dir)

      # create the new site
      new_site = Site.new
      new_site.name = name
      new_site.root_directory = site_dir
      new_site.domains << "#{name}.yodel"

      # install the standard set of folders
      FileUtils.mkdir(File.join(site_dir, Yodel::LAYOUTS_DIRECTORY_NAME))
      FileUtils.mkdir(File.join(site_dir, Yodel::MIGRATIONS_DIRECTORY_NAME))
      FileUtils.mkdir(File.join(site_dir, Yodel::PARTIALS_DIRECTORY_NAME))
      FileUtils.mkdir(File.join(site_dir, Yodel::PUBLIC_DIRECTORY_NAME))
      FileUtils.mkdir(File.join(site_dir, Yodel::ATTACHMENTS_DIRECTORY_NAME))

      # copy core yodel migrations
      yodel_migrations_dir = File.join(site_dir, Yodel::MIGRATIONS_DIRECTORY_NAME, Yodel::YODEL_MIGRATIONS_DIRECTORY_NAME)
      FileUtils.cp_r(Yodel.config.yodel_migration_directory, yodel_migrations_dir)

      # copy extension migrations
      extension_migrations_dir = File.join(site_dir, Yodel::MIGRATIONS_DIRECTORY_NAME, Yodel::EXTENSION_MIGRATIONS_DIRECTORY_NAME)
      FileUtils.mkdir(extension_migrations_dir)
      Yodel.config.extensions.each do |extension|
        FileUtils.cp_r(extension.migrations_dir, File.join(extension_migrations_dir, extension.name)) if File.directory?(extension.migrations_dir)
        new_site.extensions << extension.name
      end

      # create a blank site migrations folder
      FileUtils.mkdir(File.join(site_dir, Yodel::MIGRATIONS_DIRECTORY_NAME, Yodel::SITE_MIGRATIONS_DIRECTORY_NAME))

      # create the repository and perform the first commit
      if Yodel.config.owner_user
        if Yodel.config.owner_group != 0
          FileUtils.chown_R(Yodel.config.owner_user, Yodel.config.owner_group, site_dir)
        else
          FileUtils.chown_R(Yodel.config.owner_user, nil, site_dir)
        end
      end
      repos = Git.init(site_dir)
      repos.config('user.name', Yodel.config.remote_name)
      repos.config('user.email', Yodel.config.remote_email)
      repos.add([Yodel::LAYOUTS_DIRECTORY_NAME, Yodel::MIGRATIONS_DIRECTORY_NAME, Yodel::PARTIALS_DIRECTORY_NAME, Yodel::PUBLIC_DIRECTORY_NAME, Yodel::ATTACHMENTS_DIRECTORY_NAME])
      repos.commit_all('New yodel site')

      # save and initialise the site
      new_site.save
      Migration.run_migrations(new_site)

      # create a default admin user
      user = new_site.users.new
      user.first_name = Yodel.config.remote_name
      user.email = Yodel.config.remote_email
      user.username = Yodel.config.remote_email
      user.password = Yodel.config.remote_pass
      user.groups << new_site.groups['Developers']
      user.save

      # because of the before_create callback, we need to override
      # the salt and password manually by saving again
      user.password_salt = nil
      user.password = Yodel.config.remote_pass
      user.save_without_validation

      # redirect to the new site
      port = (request.port == 80 ? nil : request.port)
      response.redirect "http://#{new_site.domains.first}#{':' if port}#{port}/admin/pages"
    end
  end
  
  # update the root directory of a site
  respond_to :put do
    with :html do
    end
  end
end
