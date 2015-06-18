module Trough
  module Pig
    module Hooks
      def update_document_usages
        changed_chunks = content_chunks.select do |content_chunk|
          content_chunk.changed? && content_chunk.content_attribute.field_type.in?(%w(document rich_content text))
        end

        changed_chunks.each do |changed_chunk|
          send("determine_#{changed_chunk.content_attribute.field_type}_change", changed_chunk)
        end

        if deleted_at_changed?
          if deleted_at.present?
            DocumentUsage.where(pig_content_package_id: id).each(&:deactivate!)
          else
            DocumentUsage.where(pig_content_package_id: id).each(&:activate!)
          end
        end
      end

      def determine_document_change(content_chunk)
        if content_chunk.value_was.present?
          document_usage = DocumentUsage.find_or_initialize_by(
            trough_document_id: content_chunk.value_was,
            pig_content_package_id: content_chunk.content_package.id
          )
          document_usage.deactivate!
        end
        if content_chunk.value.present?
          document = Document.find(content_chunk)
          document.create_usage!(self.id) if document
        end
      end

      def determine_rich_content_change(content_chunk)
        determine_text_change(content_chunk)
      end

      def determine_text_change(content_chunk)
        documents_in_old_text = find_documents(content_chunk.value_was)
        documents_in_new_text = find_documents(content_chunk.value)

        new_documents = documents_in_new_text - documents_in_old_text
        removed_documents = documents_in_old_text - documents_in_new_text

        new_documents.each do |doc|
          document = Document.find_by(slug: doc)
          next if document.nil?
          document.create_usage!(self.id)
        end

        removed_documents .each do |doc|
          document = Document.find_by(slug: doc)
          next if document.nil?
          document_usage = DocumentUsage.find_or_initialize_by(trough_document_id: document.id, pig_content_package_id: self.id)
          document_usage.deactivate! if document_usage
        end
      end

      def find_documents(value)
        # Find all links to /documents/:slug and return the slugs
        value.scan(/href=\S*\/documents\/(\S+[^\\])\\?['"]/).flatten
      end

      def unlink_document_usages
        DocumentUsage.where(pig_content_package_id: id).each(&:unlink_content_package!)
      end
    end
  end
end
