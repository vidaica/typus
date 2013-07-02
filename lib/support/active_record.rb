class ActiveRecord::Base

  #--
  # On a model:
  #
  #     class Post < ActiveRecord::Base
  #       def self.statuses
  #         { t("Published") => "published",
  #           t("Pending") => "pending",
  #           t("Draft") => "draft" }
  #       end
  #     end
  #
  #     >> Post.first.status
  #     => "published"
  #     >> Post.first.mapping(:status)
  #     => "Published"
  #     >> I18n.locale = :es
  #     => :es
  #     >> Post.first.mapping(:status)
  #     => "Publicado"
  #++
  def mapping(attribute)
    klass = self.class
    values = klass.send(attribute.to_s.pluralize)

    array = values.first.is_a?(Array) ? values : values.map { |i| [i, i] }

    value = array.to_a.rassoc(send(attribute))
    value ? value.first : send(attribute)
  end

  def to_label
    if respond_to?(:name) && send(:name).present?
      send(:name)
    else
      [self.class, id].join("#")
    end
  end

  def self.accessible_attributes_role_for(role)
    if accessible_attributes(role).empty?
      :default
    else
      role
    end
  end

  def self.without_protection?(role)
    role = accessible_attributes_role_for(role)
    attributes = accessible_attributes(role).reject { |i| i.empty? }
    attributes.empty?
  end

end
