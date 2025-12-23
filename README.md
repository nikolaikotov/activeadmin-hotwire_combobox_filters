# ActiveAdmin Hotwire Combobox Filters

This gem adds a hotwire combobox to ActiveAdmin sidebar filters for related resources (`belongs_to`, `has_many`, etc.).

# Installation

```ruby
gem "activeadmin-hotwire_combobox_filters"
```

# Usage

The gem automatically replaces the default ActiveAdmin filters with
`hotwire_combobox` filters once it is required and configured.

### `search_fields` option

You can specify which association fields are used for searching as you type into the combobox, for example:

```ruby
filter :parent_company, search_fields: %i[name short_name code]

f.input :parent_company, search_fields: %i[name short_name code]
```

This will search the associated records by the `name`, `short_name` or `code` attributes. If `search_fields` is not set, the first available ActiveAdmin display method is used in the following order: `display_name`, `full_name`, `name`, `username`, `login`, `title`, `email` or `to_s`.

### `url` option

You can provide your own search logic, for example:

```ruby
filter :parent_company,
       url: ->(params) { my_combobox_search_admin_companies_path(params) }
```

See [lib/activeadmin_hotwire_combobox_filters/dsl.rb](lib/activeadmin_hotwire_combobox_filters/dsl.rb) for an example implementation of a search method.

# Setup

The gem requires ActiveAdmin to be wired up with Hotwire.

Here's an example setup:

1. Add to the bottom of `config/initializers/active_admin.rb`:

    ```ruby
    ActiveAdmin.importmap.draw do
      pin "@hotwired/turbo-rails", to: "turbo.min.js", preload: true
      pin "@hotwired/stimulus", to: "stimulus.min.js", preload: true
      pin "controllers/active_admin_application", preload: true
      pin "custom_active_admin", preload: true
    end
    ActiveAdmin.importmap.draw(HotwireCombobox::Engine.root.join("config/hw_importmap.rb"))
    ```

2. Create file `app/javascript/custom_active_admin.js`:

    ```js
    import "active_admin"
    import "@hotwired/turbo-rails"
    import { application } from "controllers/active_admin_application"
    import HwComboboxController from "controllers/hw_combobox_controller"
    application.register("hw-combobox", HwComboboxController)
    ```

3. Create file `controllers/active_admin_application.js`:

    ```js
    import { Application } from '@hotwired/stimulus'
    
    const application = Application.start()
    
    application.debug = false
    window.Stimulus = application
    
    export { application }
    ```
4. Change in `app/views/active_admin/_html_head.html.erb`:
    ```diff
    -<%= javascript_importmap_tags "active_admin", importmap: ActiveAdmin.importmap %>
    +<%= javascript_importmap_tags "custom_active_admin", importmap: ActiveAdmin.importmap %>
    ```

5. Add some additional styling if you want:

    ```css
    /* styles for activeadmin-hotwire_combobox_filters BEGIN */
    /* makes it look like other AA input fields */
    :root:root {
      --hw-component-bg-color: rgb(249 250 251);
    }
 
    /* makes it look like other AA input fields with validation errors */
    .formtastic .error :where(.hw-combobox__main__wrapper) {
      @apply border-red-500;
    }
 
    /* makes it wider than default hotwire_combobox styles */
    :root:root {
      --hw-combobox-width: 100%;
    }
    .hw-combobox.hw-combobox {
      @apply flex;
    }
    /* styles for activeadmin-hotwire_combobox_filters END */
    ```
   
    <details>
    <summary>Recommended way:</summary>
    
    a) Move `tailwind-active_admin.config.js` → `config/tailwind-active_admin.config.js` and change at the top:
    ```diff
    -import activeAdminPlugin from '@activeadmin/activeadmin/plugin';
    +const activeAdminPlugin = require(`${activeAdminPath}/plugin.js`);
    ```
    
    b) Rename `app/assets/stylesheets/active_admin.css` → `app/assets/stylesheets/active_admin.tailwind.css` and append proposed styles to this file.

    c) Create `bin/tasks/admin_styles.thor` with content:
    ```ruby
    class AdminStyles < Thor
      desc "build", "Build Active Admin Tailwind stylesheets"
      option :watch, type: :boolean, default: false, desc: "Watch and rebuild on changes"
      def build
        system(
          "bin/tailwindcss",
          "-i", "app/assets/stylesheets/active_admin.tailwind.css",
          "-o", "app/assets/builds/active_admin.css",
          "-c", "config/tailwind-active_admin.config.js",
          *("--watch" if options[:watch]),
          exception: true
        )
      rescue Interrupt
        # that's ok
      end
   
      desc "watch", "Watch and rebuild Active Admin Tailwind stylesheets"
      def watch
        invoke :build, nil, watch: true
      end
    end
    ```
   
    d) Run `bundle binstub tailwindcss-rails`. This will create `bin/tailwindcss` file.

    e) Append to `Procfile.dev`:
    ```
    admin_css: bin/thor admin_styles:watch
    ```

    f) Change `Rakefile`:
    ```ruby
    require_relative "config/application"
    require "thor"
    load "lib/tasks/admin_styles.thor"
    
    Rails.application.load_tasks
    
    task(:build_admin_styles) { AdminStyles.start(["build"]) }
    Rake::Task["assets:precompile"].enhance(['build_admin_styles'])
    ```

    g) Remove `cssbundling-rails` from `Gemfile`
    </details>

# Thanks and credits

Thanks to [@josefarias](https://github.com/josefarias) for the awesome [hotwire_combobox](https://github.com/josefarias/hotwire_combobox) gem.
Thanks to all the team at [ActiveAdmin](https://github.com/activeadmin/activeadmin) for the awesome gem.
