class RemotesPage < Page
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
  
end
