module Facets
  module HostgroupExtensions
    extend ActiveSupport::Concern
    include Facets::ModelExtensionsBase
    include SelectiveClone

    included do
      configure_facet(:hostgroup, :hostgroup, :hostgroup_id) do |facet_config|
        include_in_clone facet_config.name
      end
    end

    def hostgroup_ancestry_cache
      @hostgroup_ancestry_cache ||= begin
        hostgroup_facets = Facets.registered_facets.select { |_, facet| facet.has_hostgroup_configuration? }
        # return sorted list of ancestors with all facets in place
        ancestors.includes(hostgroup_facets.keys)
      end
    end

    def inherited_facet_attributes(facet_config)
      inherited_attributes = send(facet_config.name)&.inherited_attributes || {}
      hostgroup_ancestry_cache.reverse_each do |hostgroup|
        hg_facet = hostgroup.send(facet_config.name)
        next unless hg_facet
        inherited_attributes.merge!(hg_facet.inherited_attributes) { |_, left, right| left || right }
      end

      inherited_attributes
    end
  end
end
