# This file is auto-generated from the current state of the database. Instead of editing this file, 
# please use the migrations feature of ActiveRecord to incrementally modify your database, and
# then regenerate this schema definition.
#
# Note that this schema.rb definition is the authoritative source for your database schema. If you need
# to create the application database on another system, you should be using db:schema:load, not running
# all the migrations from scratch. The latter is a flawed and unsustainable approach (the more migrations
# you'll amass, the slower it'll run and the greater likelihood for issues).
#
# It's strongly recommended to check this file into your version control system.

ActiveRecord::Schema.define(:version => 21) do

  create_table "author_strings", :force => true do |t|
    t.string   "name"
    t.datetime "created_at"
    t.datetime "updated_at"
  end

  add_index "author_strings", ["name"], :name => "author_name"

  create_table "authorships", :force => true do |t|
    t.integer  "person_id"
    t.integer  "citation_id"
    t.integer  "position"
    t.datetime "created_at"
    t.datetime "updated_at"
  end

  add_index "authorships", ["person_id", "citation_id"], :name => "author_citation_join", :unique => true

  create_table "citation_author_strings", :force => true do |t|
    t.integer  "author_string_id"
    t.integer  "citation_id"
    t.integer  "position"
    t.datetime "created_at"
    t.datetime "updated_at"
  end

  create_table "citations", :force => true do |t|
    t.string   "type"
    t.string   "title_primary"
    t.string   "title_secondary"
    t.string   "title_tertiary"
    t.string   "affiliation"
    t.string   "year"
    t.string   "volume"
    t.string   "issue"
    t.string   "start_page"
    t.string   "end_page"
    t.text     "abstract"
    t.text     "notes"
    t.string   "links"
    t.string   "citation_archive_uri"
    t.string   "title_dupe_key"
    t.string   "issn_isbn_dupe_key"
    t.integer  "citation_state_id"
    t.integer  "citation_archive_state_id"
    t.integer  "publication_id"
    t.integer  "publisher_id"
    t.integer  "imported_for"
    t.integer  "bump_value"
    t.datetime "archived_at"
    t.datetime "created_at"
    t.datetime "updated_at"
    t.integer  "data_source_id"
    t.integer  "external_id"
    t.text     "serialized_data"
    t.text     "original_data"
    t.integer  "batch_index",               :default => 0
  end

  add_index "citations", ["title_dupe_key"], :name => "title_dupe"
  add_index "citations", ["issn_isbn_dupe_key"], :name => "issn_isbn_dupe"
  add_index "citations", ["citation_state_id"], :name => "fk_citation_state_id"
  add_index "citations", ["publication_id"], :name => "fk_citation_publication_id"
  add_index "citations", ["publisher_id"], :name => "fk_citation_publisher_id"
  add_index "citations", ["batch_index"], :name => "batch_index"
  add_index "citations", ["type"], :name => "fk_citation_type"

  create_table "groups", :force => true do |t|
    t.string   "name"
    t.string   "url"
    t.datetime "created_at"
    t.datetime "updated_at"
  end

  add_index "groups", ["name"], :name => "group_name", :unique => true

  create_table "keywordings", :force => true do |t|
    t.integer  "keyword_id"
    t.integer  "citation_id"
    t.integer  "position"
    t.datetime "created_at"
    t.datetime "updated_at"
  end

  add_index "keywordings", ["keyword_id", "citation_id"], :name => "keyword_citation_join", :unique => true

  create_table "keywords", :force => true do |t|
    t.string   "name"
    t.datetime "created_at"
    t.datetime "updated_at"
  end

  add_index "keywords", ["name"], :name => "keyword_name", :unique => true

  create_table "memberships", :force => true do |t|
    t.integer  "person_id"
    t.integer  "group_id"
    t.string   "title"
    t.boolean  "active"
    t.datetime "created_at"
    t.datetime "updated_at"
    t.integer  "position"
  end

  add_index "memberships", ["person_id", "group_id"], :name => "person_group_join"

  create_table "pen_names", :force => true do |t|
    t.integer  "author_string_id"
    t.integer  "person_id"
    t.datetime "created_at"
    t.datetime "updated_at"
  end

  add_index "pen_names", ["author_string_id", "person_id"], :name => "author_person_join", :unique => true

  create_table "people", :force => true do |t|
    t.integer  "external_id"
    t.string   "first_name"
    t.string   "middle_name"
    t.string   "last_name"
    t.string   "prefix"
    t.string   "suffix"
    t.string   "image_url"
    t.string   "phone"
    t.string   "email"
    t.string   "im"
    t.string   "office_address_line_one"
    t.string   "office_address_line_two"
    t.string   "office_city"
    t.string   "office_state"
    t.string   "office_zip"
    t.text     "research_focus"
    t.boolean  "active"
    t.datetime "created_at"
    t.datetime "updated_at"
  end

  create_table "publications", :force => true do |t|
    t.integer  "sherpa_id"
    t.integer  "publisher_id"
    t.integer  "source_id"
    t.integer  "authority_id"
    t.string   "name"
    t.string   "url"
    t.string   "code"
    t.string   "issn_isbn"
    t.datetime "created_at"
    t.datetime "updated_at"
    t.string   "place"
  end

  add_index "publications", ["publisher_id"], :name => "fk_publication_publisher_id"
  add_index "publications", ["authority_id"], :name => "fk_publication_authority_id"
  add_index "publications", ["name"], :name => "publication_name"
  add_index "publications", ["issn_isbn"], :name => "issn_isbn"

  create_table "publishers", :force => true do |t|
    t.integer  "sherpa_id"
    t.integer  "source_id"
    t.integer  "authority_id"
    t.boolean  "publisher_copy"
    t.string   "name"
    t.string   "url"
    t.string   "romeo_color"
    t.string   "copyright_notice"
    t.datetime "created_at"
    t.datetime "updated_at"
  end

  add_index "publishers", ["name"], :name => "publisher_name", :unique => true
  add_index "publishers", ["authority_id"], :name => "fk_publisher_authority_id"

  create_table "taggings", :force => true do |t|
    t.integer  "tag_id"
    t.integer  "taggable_id"
    t.string   "taggable_type"
    t.datetime "created_at"
  end

  add_index "taggings", ["tag_id"], :name => "index_taggings_on_tag_id"
  add_index "taggings", ["taggable_id", "taggable_type"], :name => "index_taggings_on_taggable_id_and_taggable_type"

  create_table "tags", :force => true do |t|
    t.string "name"
  end

  add_index "tags", ["name"], :name => "tag_name", :unique => true

end