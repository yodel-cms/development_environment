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
    # clone a site from a remote server
    with :json do
      # ensure yodel is set up
      default_user = site.default_users.first
      return {success: false, reason: 'No default user has been created'} if site.default_users.count == 0
      
      # extract the site name and generate an identifier to be used as the site's domain and folder name
      name = params['name'].to_s
      return {success: false, reason: 'No site name provided'} if name.blank?
      
      # find the remote to clone from
      remote = Remote.find(BSON::ObjectId.from_string(params['remote']))
      return {success: false, reason: 'Remote could not be found'} if remote.nil?      
      remote_id = params['remote_id']

      new_site = Site.clone(name, remote, remote_id, default_user)
      if new_site.is_a?(String)
        {success: false, reason: new_site}
      else
        {success: true, url: new_site_url(new_site)}
      end
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
      
      name = params['name'].sub('.yodel', '')
      if name.blank?
        flash[:error] = 'You must enter a name for this site'
        response.redirect '/sites'
        return
      end
      
      new_site = Site.create(name, default_user)
      response.redirect new_site_url(new_site)
    end
  end
  
  private
    def new_site_url(new_site)
      port = (request.port == 80 ? nil : request.port)
      "http://#{new_site.domains.first}#{':' if port}#{port}/admin/pages"
    end
end
