class WorksController < ApplicationController
  #require CMess to help guess encoding of uploaded text files
  require 'cmess/guess_encoding'

  #Require a user be logged in to create / update / destroy
  before_filter :login_required,
                :only => [:new, :create, :edit, :update, :destroy, :destroy_multiple, :merge_duplicates,
                          :orphans]

  before_filter :find_authorities, :only => [:new, :edit]

  make_resourceful do
    build :show, :new, :edit, :destroy

    publish :xml, :json, :yaml, :only => :show, :attributes => [
        :id, :type, :title_primary, :title_secondary, :title_tertiary,
        :year, :volume, :issue, :start_page, :end_page, :links, :tags, {
            :publication => [:id, :name]
        }, {
            :publisher => [:id, :name]
        }, {
            :name_strings => [:id, :name]
        }, {
            :people => [:id, :first_last]
        }
    ]

    #Add a response for METS!
    response_for :show do |format|
      format.html #loads show.html.haml (HTML needs to be first, so I.E. views it by default)
      format.mets #loads show.mets.haml
      format.rdf
    end

    response_for :index do |format|
      format.html
      format.xml
      format.yaml
      format.json
      format.rdf
    end

    #initialize variables used by 'new.html.haml'
    before :new do

      #check if we are adding new works directly to a person
      person_from_person_id

      if @person
        #If adding to a person, must be an 'editor' of that person
        permit "editor on person"
      else
        #Default: anyone with 'editor' role (anywhere) can add works
        permit "editor"
      end

      #if 'type' unspecified, default to first type in list
      params[:klass] ||= Work.types[0]

      #initialize work subclass with any passed in work info
      @work = subklass_init(params[:klass], params[:work])

    end

    before :show do
      @recommendations = Index.recommendations(@current_object)
      # Specify text at end of HTML title tag
      @title = @current_object.title_primary
      true
    end

    before :edit do
      #Anyone with 'editor' role on this work can edit it
      permit "editor on Work"

      #Check if there was a path passed along to return to
      @return_path = params[:return_path]
    end

    before :destroy do
      #Anyone with 'admin' role on this work can destroy it
      permit "admin on Work"
    end

  end # end make_resourceful

  def index
    if params[:person_id]
      @current_object = Person.find_by_id(params[:person_id].split("-")[0])
      @person = @current_object
      search(params)
    elsif params[:group_id]
      @current_object = Group.find_by_id(params[:group_id].split("-")[0])
      @group = @current_object
      search(params)
    elsif params[:format] == "rdf"
      params[:rows] = 100
      search(params)
    else
      logger.debug("\n\n===Works: #{@current_object.inspect}")
      # Default BibApp search method - ApplicationController

      #Solr filter query for active people
      params[:fq] ||= []
      params[:fq] << "person_active:true"
      search(params)
    end
  end

  def orphans
    permit "editor for Work"
    @title = 'Orphaned works'
    @orphans = Work.orphans.paginate(:page => params[:page] || 1, :per_page => params[:per_page] || 20)
  end

  def orphans_delete
    permit "editor for Work"
    if params[:orphan_delete]
      Work.find(params[:orphan_delete][:orphan_id]).each do |w|
        w.destroy
      end
    end
    redirect_to orphans_works_url(:page => params[:page], :per_page => params[:per_page])
  end

  def change_type
    t = params[:type]
    klass = t.constantize
    work = Work.find(params[:id])

    # lazy mapping of all creator/contributor roles to top creator role
    authors = work.work_name_strings.collect { |wns| [:name=>wns.name_string.name, :role=>t.constantize.creator_role] }

    work.update_type_and_save(t) if t
    work.set_work_name_strings authors

    Index.update_solr(work)

    respond_to do |format|
      format.html { redirect_to edit_work_path(work.id) }
      format.xml { head :ok }
    end
  end

  # For paging make_resourceful publish
  def current_objects
    page = params[:page] || 1
    @current_object ||= current_model.order("created_at DESC").paginate(:page => page, :per_page => 10)
  end

  #Create a new Work or many new Works
  def create
    #check if we are adding new works directly to a person
    person_from_person_id

    if @person
      #If adding to a person, must be an 'editor' of that person
      permit "editor on person"
    else
      #Default: anyone with 'editor' role (anywhere) can add works
      permit "editor"
    end

    #Check if user hit cancel button
    if params['cancel']
      #just return back to 'new' page
      respond_to do |format|
        format.html { redirect_to new_work_url }
        format.xml { head :ok }
      end

    else #Only perform create if 'save' button was pressed

      logger.debug("\n\n===ADDING SINGLE WORK===\n\n")

      # Create the basic Work SubKlass
      @work = subklass_init(params[:klass], params[:work])


      #Create attribute hash
      r_hash = create_attribute_hash

      work_id, errors = Work.create_from_hash(r_hash)

      # current user automatically gets 'admin' permissions on work
      # (only if he/she doesn't already have that permission)
      work_from_work_id(work_id)

      #If this was submitted as an individual work for a specific person then
      #automatically verify the contributorship
      if @work and @person
        c = Contributorship.for_person(@person.id).for_work(@work.id).first
        c.verify_contributorship if c
      end

      respond_to do |format|
        if work_id
          flash[:notice] = "Work was successfully created."
          format.html { redirect_to work_url(work_id) }
          format.xml { head :created, :location => work_url(work_id) }
        else
          flash[:notice] = errors
          format.html { render :action => "new" }
          format.xml { render :xml => error.to_xml }
        end
      end

    end #If 'save' button was pressed
  end

  def merge_duplicates
    #Anyone with 'editor' role on this work can edit it
    @work = Work.find(params[:id])
    permit "editor on work"
    @dupe = Work.find(params[:dupe_id])
  end

  def update

    @work = Work.find(params[:id])

    #Check if there was a path and page passed along to return to
    return_path = params[:return_path]

    #Check if user hit cancel button
    if params['cancel']
      # just return back from where we came
      respond_to do |format|
        unless return_path.nil?
          format.html { redirect_to return_path }
        else
          #default to returning to work page
          format.html { redirect_to work_url(@work) }
        end
        format.xml { head :ok }
      end

    else #Only perform update if 'save' button was pressed
         #Anyone with 'editor' role on this work can edit it
      permit "editor on work"

      #First, update work attributes (ensures deduplication keys are updated)
      @work.attributes=params[:work]

      #Then, update other work information
      #update_work_info

      # Create attribute hash from params
      r_hash = create_attribute_hash

      work_id, errors = @work.update_from_hash(r_hash)

      work_from_work_id(work_id)

      respond_to do |format|
        if work_id
          flash[:notice] = "Work was successfully updated."
          if return_path.nil?
            #default to returning to work page
            format.html { redirect_to work_path(@work.id) }
          else
            format.html { redirect_to return_path }
          end
          format.xml { head :ok }
        else
          flash[:notice] = errors
          format.html { redirect_to edit_work_path(@work.id) }
          format.xml { render :xml => errors.to_xml }
        end
      end #end respond to
    end
  end

  def destroy
    permit "admin"

    work = Work.find(params[:id])
    return_path = params[:return_path] || works_url

    full_success = true

    #Find all possible dupe candidates from Solr, if any
    dupe_candidates = Index.possible_unaccepted_duplicate_works(work)

    #if this is an unaccepted work, it will show up in the list, so remove it first
    dupe_candidates.delete(work)

    if dupe_candidates.empty?
      #Destroy the work
      work.destroy
    else
      #can't destroy an accepted work that has duplicates
      if work.work_state_id != 3
        work.destroy
      else
        full_success = false
      end
    end


    respond_to do |format|
      if full_success
        flash[:notice] = "Works were successfully deleted."
        #forward back to path which was specified in params
        format.html { redirect_to return_path }
        format.xml { head :ok }
      else
        flash[:warning] = "This work has duplicates, which must be altered or deleted before this work can be deleted."
        format.html { redirect_to edit_work_path(work.id) }
        format.xml { head :ok }
      end
    end
  end

  def destroy_multiple
    #Anyone who is minimally an admin (on anything in system) can delete works
    #(NOTE: User will actually have to be an 'admin' on all works in this batch,
    #       otherwise he/she will not be able to destroy *all* the works)
    permit "admin"

    work_ids = params[:work_id]
    return_path = params[:return_path]

    full_success = true

    if work_ids.present?
      #Destroy each work one by one, so we can be sure user has 'admin' rights on all
      work_ids.each do |work_id|
        work = Work.find_by_id(work_id)

        #One final check...only an admin on this work can destroy it
        if logged_in? && current_user.has_role?("admin", work)
          work.destroy
        else
          full_success = false
        end
      end
    end

    respond_to do |format|
      if full_success
        flash[:notice] = "Works were successfully deleted."
      else
        flash[:warning] = "One or more works could not be deleted, as you have insufficient privileges"
      end
      #forward back to path which was specified in params
      format.html { redirect_to return_path }
      format.xml { head :ok }
    end
  end


  # Load name strings list from Request params
  # and set for the current work.
  # Also sets the instance variable @author_name_strings,
  # in case any errors should occur in saving work
  def set_author_name_strings(work)
    @author_name_strings = Array.new
    set_contributor_name_strings(work, @author_name_strings, :author_name_strings, 'Author')
  end

  # Load name strings list from Request params
  # and set for the current work.
  # Also sets the instance variable @editor_name_strings,
  # in case any errors should occur in saving work
  def set_editor_name_strings(work)
    @editor_name_strings = Array.new
    set_contributor_name_strings(work, @editor_name_strings, :editor_name_strings, 'Editor')
  end

  def set_contributor_name_strings(work, accumulator, parameter_key, role)
    params[parameter_key] ||= []
    params[parameter_key].each do |name|
      name_string = NameString.find_or_initialize_by_name(name)
      accumulator << {:name => name_string, :role => role}
    end
    work.set_work_name_strings(accumulator)
  end

  #Auto-Complete for entering Author NameStrings in Web-based Work entry
  def auto_complete_for_author_string
    auto_complete_for_name_string(params[:author][:string])
  end

  #Auto-Complete for entering Editor NameStrings in Web-based Work entry
  def auto_complete_for_editor_string
    auto_complete_for_name_string(params[:editor][:string])
  end

  #Auto-Complete for entering NameStrings in Web-based Work entry
  #  This method provides users with a list of matching NameStrings
  #  already in BibApp.
  def auto_complete_for_name_string(name_string)
    name_string = name_string.downcase

    #search at beginning of name
    beginning_search = name_string + "%"
    #search at beginning of any other words in name
    word_search = "% " + name_string + "%"

    names = NameString.where("LOWER(name) LIKE ? OR LOWER(name) LIKE ?",
                             beginning_search, word_search).order_by_name.limit(8).collect { |ns| ns.name }

    render :partial => 'works/forms/fields/autocomplete_list', :locals => {:objects => names}
  end

  def auto_complete_for_keyword_name
    auto_complete_for_name(params[:keyword][:name])
  end

  def auto_complete_for_tag_name
    auto_complete_for_name(params[:tag][:name])
  end

  #provide matching keywords or tags for autocomplete based off of the supplied name
  def auto_complete_for_name(name)
    name = name.downcase

    #search at beginning of word
    beginning_search = name + "%"
    #search at beginning of any other words
    word_search = "% " + name + "%"

    #Search both keywords and tags
    keywords = Keyword.where("LOWER(name) LIKE ? OR LOWER(name) LIKE ?",
                             beginning_search, word_search).order_by_name.limit(8)

    tags = Tag.where("LOWER(name) LIKE ? OR LOWER(name) LIKE ?",
                     beginning_search, word_search).order_by_name.limit(8)

    #Combine both lists
    keywords_and_tags = (keywords + tags).collect { |x| x.name }

    render :partial => 'works/forms/fields/autocomplete_list', :locals => {:objects => keywords_and_tags.uniq.sort.first(8)}
  end

  #Auto-Complete for entering Publication Titles in Web-based Work entry
  #  This method provides users with a list of matching Publications
  #  already in BibApp.
  def auto_complete_for_publication_name
    publication_name = params[:publication][:name].downcase

    #search at beginning of name
    beginning_search = publication_name + "%"
    #search at beginning of any other words in name
    word_search = "% " + publication_name + "%"

    publications = Publication.where("LOWER(name) LIKE ? OR LOWER(name) LIKE ?",
                                     beginning_search, word_search).order_by_name.limit(8)

    render :partial => 'works/forms/fields/publication_autocomplete_list', :locals => {:publications => publications}
  end

  #Auto-Complete for entering Publisher Name in Web-based Work entry
  #  This method provides users with a list of matching Publishers
  #  already in BibApp.
  def auto_complete_for_publisher_name
    publisher_name = params[:publisher][:name].downcase

    #search at beginning of name
    beginning_search = publisher_name + "%"
    #search at beginning of any other words in name
    word_search = "% " + publisher_name + "%"

    publishers = Publisher.where("LOWER(name) LIKE ? OR LOWER(name) LIKE ?",
                                 beginning_search, word_search).order_by_name.limit(8)

    render :partial => 'works/forms/fields/autocomplete_list', :locals => {:objects => publishers}
  end

  #Adds a single item value to list of items in Web-based Work entry
  # This is used to add multiple values in form (e.g. multiple NameStrings, Keywords, etc)
  # Expects three parameters:
  # 	list_type - "Name" of type of list (e.g. "author_name_strings", "keywords")
  #     clear_field - Name of form field to clear after processing is complete
  #     item_value - value to add to item list
  #     item_class - (optional) any extra CSS classes to add to the <li> tag
  #     sortable - whether or not this list is sortable (i.e. able to be reordered)
  #
  # (E.g.) item_name=>"author_name_strings", item_value=>"Donohue, Tim", clear_field=>"author_string"
  #	  Above example will add value "Donohue, Tim" to list of author values in form.
  #   Specifically, it would add a new <li> to the <ul> or <ol> with an ID of "author_name_strings_list".
  #   It then clears the "author_string" field (which is the textbox where the value was entered).
  #
  # See 'item_list.js.rjs' for much more information, as this file includes the
  # Javascript to add and remove items.
  def add_item_to_list
    @list_type = params[:list_type]
    @clear_field = params[:clear_field]
    @item_value = params[:item_value]
    @item_class = params[:item_class]
    @sortable = params[:sortable]
    @update_action = 'add'

    #Add item value to list dynamically using Javascript
    render :template => 'works/forms/fields/update_item_list'
  end

  def add_contributor_to_list
    add_collaborator_to_list("contributor_name_strings", 'add_contributor')
  end

  def add_author_to_list
    add_collaborator_to_list("author_name_strings", "add_author")
  end

  def add_collaborator_to_list(list_type, update_action)
    @ns_id = params[:ns_id]
    @sortable = true
    @list_type = list_type
    @update_action = update_action
    @work = subklass_init(params[:work_type], nil)
    render :template => 'works/forms/fields/update_item_list'
  end

  #Removes a single item value from list of items in Web-based Work entry
  # This is used to remove from multiple values in form (e.g. multiple authors, keywords, etc)
  # Expects two parameters:
  #   list_type -  Type of list (e.g. "author_name_strings", "keywords")
  #   item_id   -  ID of item to remove
  #
  # Essentially this does the opposite of 'add_item_to_list', and removes
  # an existing item.
  #
  # See 'item_list.js.rjs' for much more information, as this file includes the
  # Javascript to add and remove items.
  def remove_item_from_list
    @list_type = params[:list_type]
    @item_id = params[:item_id]
    @update_action = 'remove'

    #remove item value from list dynamically using Javascript
    render :template => 'works/forms/fields/update_item_list'
  end

  def remove_contributor_from_list
    remove_collaborator_from_list('remove_contributor')
  end

  def remove_author_from_list
    remove_collaborator_from_list('remove_author')
  end

  def remove_collaborator_from_list(update_action)
    @ns_id = params[:ns_id]
    @update_action = update_action
    #remove item value from list using Javascript
    render :template => 'works/forms/fields/update_item_list'
  end

  # Reorders a list using Scriptaculous's 'sortable_element'
  def reorder_list
    list_type = params[:list_type]

    #display message that reorder was successful
    render :partial => 'works/forms/fields/reorder_list', :locals => {:list_type=>list_type}
  end

  def update_tags
    @work = Work.find(params[:id])
    ###
    # Setting Tags
    ###
    # Save tags to instance variable @tags,
    # in case any errors should occur in saving work
    @tags = params[:tags]
    @work.set_tag_strings(@tags)

    respond_to do |format|
      if @work.save and Index.update_solr(@work)
        flash[:notice] = "Work was successfully updated."
        format.html { redirect_to work_url(@work) }
        format.xml { head :ok }
      else
        format.html { render :action => "edit" }
        format.xml { render :xml => @work.errors.to_xml }
      end
    end
  end

  private

  # Initializes a new work subclass, but doesn't create it in the database
  def subklass_init(klass_type, work)
    klass_type.gsub!(" ", "") #remove spaces
    klass_type.gsub!("/", "") #remove slashes
    klass_type.gsub!(/[()]/, "") #remove any parens
    klass = klass_type.constantize #change into a class
    if klass.superclass != Work
      raise NameError.new("#{klass_type} is not a subclass of Work") and return
    end
    klass.new(work)
  end

  def find_authorities
    @publication_authorities = Publication.authorities.order_by_name
    @publisher_authorities = Publisher.authorities.order_by_name
  end

  # Initialize information about the last batch of works
  # that was added during this current user's session
  def init_last_batch
    last_batch = find_last_batch

    #clear last batch if not empty
    last_batch.clear unless last_batch.empty?

    #return cleared batch
    return last_batch
  end

  # Find the last batch of works that was added during
  # this current user's session.  Only work_ids are stored.
  def find_last_batch
    session[:works_batch] ||= Array.new

    # Quick cleanup of batch...remove any items which have been deleted
    session[:works_batch].delete_if { |work_id| !Work.exists?(work_id) }
  end

  def person_from_person_id
    if params[:person_id]
      @person = Person.find(params[:person_id].split("-")[0])
    end
  end

  def work_from_work_id(work_id)
    if work_id
      @work = Work.find(work_id)
      @work.accepts_role 'admin', current_user unless !current_user.has_role?('admin', @work)
    end
  end

  # Create a hash of Work attributes
  # This is called by both create() and update()
  def create_attribute_hash

    attr_hash = Hash.new
    attr_hash[:klass] = params[:klass]

    attr_hash[:person_id] = params[:person_id]

    ###
    # Setting WorkNameStrings
    ###

    #default to empty array
    params[:authors] ||= []
    params[:contributors] ||= []
    params[:author_roles] ||= []
    params[:contributor_roles] ||= []

    #Set Author & Editor NameStrings for this Work
    @work_name_strings = Array.new
    @author_name_strings = Array.new
    @editor_name_strings = Array.new

    accumulate_names_and_roles(params[:authors], params[:author_roles],
                               [@author_name_strings, @work_name_strings])
    accumulate_names_and_roles(params[:contributors], params[:contributor_roles],
                               [@editor_name_strings, @work_name_strings])

    attr_hash[:work_name_strings] = @work_name_strings

    ###
    # Setting Keywords
    ###
    # Save keywords to instance variable @keywords,
    # in case any errors should occur in saving work
    @keywords = params[:keywords].split(';').collect { |kw| kw.squish } if params[:keywords].present?
    attr_hash[:keywords] = @keywords

    ###
    # Setting Tags
    ###
    # Save tags to instance variable @tags,
    # in case any errors should occur in saving work
    #@tags = params[:tags]
    #@work.set_tag_strings(@tags)

    ###
    # Setting Publication Info, including Publisher
    ###
    @publication = Publication.new
    @publisher = Publisher.new
    @publication.issn_isbn = params[:issn_isbn]

    # Sometimes there will be no publication, sometimes it will be blank,
    # sometimes it will have a value. If it's nil or blank we still want
    # to have the @publication[:name] hash in case we're sent back to
    # the 'new' page due to a save error.
    @publication.name = params[:publication][:name] rescue nil
    @publisher.name = params[:publisher][:name] rescue nil

    attr_hash[:issn_isbn] = @publication.issn_isbn
    attr_hash[:publication] = @publication.name
    attr_hash[:publisher] = @publisher.name

    params[:work].each do |key, val|
      attr_hash[key.to_sym] = val
    end

    return attr_hash.delete_if { |key, val| val.blank? }

  end

  #name_array and role_array are parallel arrays
  #whenever the stripped name is not blank add a hash to each accumulator
  #of the form :name => name, :role => role
  def accumulate_names_and_roles(name_array, role_array, accumulators)
    name_array.zip(role_array).each do |row|
      name, role = row
      name.strip!
      unless name.blank?
        accumulators.each do |acc|
          acc << {:name => name, :role => role}
        end
      end
    end
  end

end