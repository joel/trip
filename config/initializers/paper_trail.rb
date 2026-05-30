# frozen_string_literal: true

# Serialize version snapshots as JSON rather than the default YAML.
#
# Psych 4's safe_load rejects ActiveSupport::TimeWithZone (and other rich
# types) on reify, raising Psych::DisallowedClass. The JSON serializer sidesteps
# this entirely: object / object_changes are stored as JSON in the text columns
# and reify reassigns plain values that Active Record type-casts back. This is
# the reliable path for restoring a prior title/content revision.
PaperTrail.serializer = PaperTrail::Serializers::JSON
