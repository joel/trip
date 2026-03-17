# frozen_string_literal: true

class RodauthApp < Rodauth::Rails::App
  unless BuildTasks.assets_precompile?
    configure RodauthMain
    route(&:rodauth)
  end
end
