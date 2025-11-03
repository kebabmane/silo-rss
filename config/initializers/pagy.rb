require 'pagy/extras/overflow'

Pagy::DEFAULT[:size] = [1, 4, 4, 1]     # nav size
Pagy::DEFAULT[:page_param] = :page      # page param name
Pagy::DEFAULT[:items] = 20              # items per page
