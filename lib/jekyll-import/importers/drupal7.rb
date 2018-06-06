require "jekyll-import/importers/drupal_common"

module JekyllImport
  module Importers
    class Drupal7 < Importer
      include DrupalCommon
      extend DrupalCommon::ClassMethods

      def self.build_query(prefix, types, engine)
        types = types.join("' OR n.type = '")
        types = "n.type = '#{types}'"

        if engine == "postgresql"
          tag_group = <<EOS
            (SELECT STRING_AGG(td.name, '|')
            FROM taxonomy_term_data td, taxonomy_index ti
            WHERE ti.tid = td.tid AND ti.nid = n.nid) AS tags
EOS
        else
          tag_group = <<EOS
            (SELECT GROUP_CONCAT(td.name SEPARATOR '|')
            FROM taxonomy_term_data td, taxonomy_index ti
            WHERE ti.tid = td.tid AND ti.nid = n.nid) AS 'tags'
EOS
          img_ids_group = <<EOS
          (SELECT GROUP_CONCAT(imgids.field_image_fid)
          FROM field_data_field_image imgids
          WHERE imgids.entity_id = n.nid) AS 'image_ids'

EOS

        end

        query = <<EOS
                SELECT n.nid,
                       n.title,
                       fdb.body_value,
                       fdb.body_summary,
                       n.created,
                       n.status,
                       pb.field_publication_date_value,
                       w1.field_website_name_value,
                       w2.field_website_link_value,
                       w3.field_webpage_value,
                       w4.field_acronym_value,
                       n.type,
                       #{tag_group},
                       #{img_ids_group}

                FROM #{prefix}node AS n
                LEFT JOIN #{prefix}field_data_body AS fdb
                  ON fdb.entity_id = n.nid AND fdb.entity_type = 'node'

                LEFT JOIN #{prefix}field_data_field_publication_date AS pb
                  ON pb.entity_id = n.nid AND pb.entity_type = 'node'

                LEFT JOIN #{prefix}field_data_field_website_name AS w1
                  ON w1.entity_id = n.nid AND w1.entity_type = 'node'

                LEFT JOIN #{prefix}field_data_field_website_link AS w2
                  ON w2.entity_id = n.nid AND w2.entity_type = 'node'

                LEFT JOIN #{prefix}field_data_field_webpage AS w3
                  ON w3.entity_id = n.nid AND w3.entity_type = 'node'

                LEFT JOIN #{prefix}field_data_field_acronym AS w4
                  ON w4.entity_id = n.nid AND w4.entity_type = 'node'

                LEFT JOIN #{prefix}field_data_field_image AS im
                  ON im.entity_id = n.nid AND im.entity_type = 'node'
                  
                WHERE (#{types})
EOS
        #abort query
        return query
      end

      def self.aliases_query(prefix)
        "SELECT source, alias FROM #{prefix}url_alias WHERE source = ?"
      end

      def self.post_data(sql_post_data)
        content = sql_post_data[:body_value].to_s
        summary = sql_post_data[:body_summary].to_s
        tags = (sql_post_data[:tags] || "").downcase.strip
        img_ids = (sql_post_data[:image_ids]).to_s
        img_ids = img_ids.split(",").map { |s| s.to_i }
        images = Array.new

        data = {
          "excerpt"    => summary,
          "categories" => tags.split("|"),
          "img_ids" => img_ids,
          "images" => images,
          "publication_date" => sql_post_data[:field_publication_date_value],
          "website_name" => sql_post_data[:field_website_name_value],
          "website_link" => sql_post_data[:field_website_link_value],
          "webpage" => sql_post_data[:field_webpage_value],
          "acronym" => sql_post_data[:field_acronym_value],
        }

        return data, content
      end
    end
  end
end
