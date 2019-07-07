def nuix_worker_item_callback(worker_item)
    # EDIT: The absolute path to the avian scripts directory.
    path = 'REPLACE WITH PATH TO DIRECTORY'

    scripts = [ # EDIT: List of all worker side scripts that should be executed, in order.
    'example script one', # This list is not case-sensitive,
    'example_script_two', # and all spaces and underscores are ignored.
    'eXample_scRiPtTHREe' # You can add as many as you like, just remember to end all lines but the last with a comma.
    ]
    
    # Actually runs the scripts. Do not touch.
    path.gsub!('\\', '/')
    load (path + '/wss_dispatcher.rb')
    dispatch_scripts(path, scripts, worker_item)
end