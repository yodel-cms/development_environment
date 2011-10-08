class RemotesPage < RecordProxyPage
  # record proxy pages deal with site models (site.model_name). Override the methods it uses
  # to interact with these models we can edit Remotes (a non site model)
  def record
    @record ||= Remote.find(BSON::ObjectId.from_string(params['id']))
  end
  
  def records
    @records ||= Remote.all
  end
  
  def new_record
    Remote.new
  end

  def form_for_new_record(options={}, &block)
    form_for(Remote.new, options, &block)
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
end
