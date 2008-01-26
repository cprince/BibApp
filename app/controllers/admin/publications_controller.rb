class Admin::PublicationsController < ApplicationController

  make_resourceful do
    build :index, :show, :new, :edit, :create, :update
    
    before :index do
      if params[:q]
        query = params[:q]
        @current_objects = current_objects
      else
        @current_objects = Publication.paginate(
          :all,
          :conditions => ["id = authority_id"],
          :order => "name",
          :page => params[:page] || 1,
          :per_page => 30
        )
      end      
    end
    
    before :show do      
      @citations = Citation.paginate(
        :all,
        :conditions => ["publication_id = ? and citation_state_id = ?", current_object.id, 3],
        :order => "year DESC, title_primary",
        :page => params[:page] || 1,
        :per_page => 10
      )
      
      @authority_for = Publication.find(
        :all,
        :conditions => ["authority_id = ?", current_object.id],
        :order => "name"
      )
    end

    before :new, :edit do
      @publishers = Publisher.find(:all, :conditions => ["id = authority_id"], :order => "name")
      @publications = Publication.find(:all, :conditions => ["id = authority_id"], :order => "name")
    end
  end
  
  def update_multiple
    pub_ids = params[:pub_ids]
    auth_id = params[:auth_id]
    update = Publication.update_multiple(pub_ids, auth_id)
    
    respond_to do |wants|
      wants.html do
        redirect_to :action => 'index', :page => params[:page]
      end
    end
  end

  private
  def current_objects
    #TODO: If params[:q], handle multiple request types:
    # * ISSN
    # * ISBN
    # * Name (abbreviations)
    # * Publisher
    @current_objects ||= current_model.find_all_by_issn_isbn(params[:q])
  end
end
