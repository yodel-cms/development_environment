$('.remote_site a').live('click', function(event) {
  var link = $(this);
  link.addClass('cloning');
  
  jQuery.ajax('/sites.json', {data: {remote: link.attr('data-remote'), remote_id: link.attr('data-remote-id'), name: link.attr('data-site-name')}, type: 'POST', success: function(data) {
    if(data.success)
      if(data.url)
        window.location = data.url;
      else
        alert("The site was created successfully, but no default url was returned. Please try refreshing this page, and visiting the site manually.");
    else
      alert("Sorry, an error occurred while cloninng this site: " + data.reason);
	}, error: function(jqXHR, textStatus, errorThrown) {
	  alert("Sorry, an error occurred while cloning this site.");
	}, complete: function(jqXHR, textStatus) {
	  link.removeClass('cloning');
	}});
});
