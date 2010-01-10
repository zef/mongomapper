module MongoMapper
  module NestedAttributes
    def self.included(base)
      base.extend(ClassMethods)
      base.send :include, InstanceMethods
    end

    module ClassMethods
      def accepts_nested_attributes_for(*attr_names)
        options = { :allow_destroy => false }
        options.update(attr_names.extract_options!)
        options.assert_valid_keys(:allow_destroy, :reject_if)


        for association_name in attr_names
          if associations.any? { |key, value| key == association_name.to_s }
            module_eval %{
              def #{association_name}_attributes=(attributes)
                assign_nested_attributes_for_association(:#{association_name}, attributes, #{options[:allow_destroy]})
              end
              }, __FILE__, __LINE__
              # assign_nested_attributes_for_#{type}_association(:#{association_name}, attributes, #{options[:allow_destroy]})
            else
              raise ArgumentError, "No association found for name `#{association_name}'. Has it been defined yet?"
            end
          end
        end

    end

    module InstanceMethods
      UNASSIGNABLE_KEYS = %w{ id _id _destroy }

      def assign_nested_attributes_for_association(association_name, attributes_collection, allow_destroy)
        unless attributes_collection.is_a?(Hash) || attributes_collection.is_a?(Array)
          raise ArgumentError, "Hash or Array expected, got #{attributes_collection.class.name} (#{attributes_collection.inspect})"
        end

        if attributes_collection.is_a? Hash
          attributes_collection = attributes_collection.sort_by { |index, _| index.to_i }.map { |_, attributes| attributes }
        end


        attributes_collection.each do |attributes|
          attributes.stringify_keys!

          if attributes['_id'].blank?
            send(association_name) << association_name.to_s.classify.constantize.new(attributes)
          elsif existing_record = send(association_name).detect { |record| record.id.to_s == attributes['_id'].to_s }
            if existing_record.has_destroy_flag?(attributes)
              send(association_name).delete(existing_record)
              existing_record.destroy unless association_name.to_s.classify.constantize.embeddable?
            else
              existing_record.attributes = attributes.except(*UNASSIGNABLE_KEYS)
            end
          end
        end

        #   unless reject_new_record?(association_name, attributes)
        #     send("build_#{association_name}", attributes.except(*UNASSIGNABLE_KEYS))
        #   end
        # elsif (existing_record = send(association_name)) && existing_record.id.to_s == attributes['id'].to_s
        #   assign_to_or_mark_for_destruction(existing_record, attributes, allow_destroy)
        # end
      end

      # Determines if a hash contains a truthy _destroy key.
      def has_destroy_flag?(hash)
        Boolean.to_mongo(hash['_destroy'])
      end

    end
  end
end
