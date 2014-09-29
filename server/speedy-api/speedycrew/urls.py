from django.conf.urls import patterns, include, url

# Uncomment the next two lines to enable the admin:
# from django.contrib import admin
# admin.autodiscover()

urlpatterns = patterns('',
    url(r'^api/1/docs$', 'scapi1.views.docs', name='docs'),
    
    url(r'^api/1/tags$', 'scapi1.views.tags', name='tags'),
    url(r'^api/1/profile$', 'scapi1.views.profile', name='profile'),
    url(r'^api/1/update_profile$', 'scapi1.views.update_profile', name='update_profile'),
    url(r'^api/1/set_notification$', 'scapi1.views.set_notification', name='set_notification'),

    url(r'^api/1/searches$', 'scapi1.views.searches', name='searches'),
    url(r'^api/1/create_search$', 'scapi1.views.create_search', name='create_search'),
    url(r'^api/1/search_results$', 'scapi1.views.search_results', name='search_results'),
    url(r'^api/1/delete_search$', 'scapi1.views.delete_search', name='delete_search'),

    url(r'^api/1/create_crew$', 'scapi1.views.create_crew', name='create_crew'),
    url(r'^api/1/invite_crew$', 'scapi1.views.invite_crew', name='invite_crew'),
    url(r'^api/1/kick_crew$', 'scapi1.views.kick_crew', name='kick_crew'),
    url(r'^api/1/leave_crew$', 'scapi1.views.leave_crew', name='leave_crew'),
    url(r'^api/1/rename_crew$', 'scapi1.views.rename_crew', name='rename_crew'),

    url(r'^api/1/send_message$', 'scapi1.views.send_message', name='send_message'),

    url(r'^api/1/media/([0-9a-zA-Z:]+)$', 'scapi1.views.media_list', name='media_list'),
    url(r'^api/1/media/([0-9a-zA-Z:]+)/([^/?]+)$', 'scapi1.views.media', name='media'),

    url(r'^api/1/trending$', 'scapi1.views.trending', name='trending'),

    url(r'^api/1/synchronise$', 'scapi1.views.synchronise', name='synchronise'),

    url(r'^monitoring/dashboard$', 'scapi1.views.dashboard', name='dashboard'),

    # Examples:
    # url(r'^$', 'speedycrew.views.home', name='home'),
    # url(r'^speedycrew/', include('speedycrew.foo.urls')),

    # Uncomment the admin/doc line below to enable admin documentation:
    # url(r'^admin/doc/', include('django.contrib.admindocs.urls')),

    # Uncomment the next line to enable the admin:
    # url(r'^admin/', include(admin.site.urls)),
)
