class PublicationsController < ApplicationController
  include PubCommonHelper

  #Require a user be logged in to create / update / destroy
  before_filter :login_required, :only => [:new, :create, :edit, :update, :destroy]

  make_resourceful do
    build :index, :show, :new, :edit, :create, :update

    publish :yaml, :xml, :json, :attributes => [
        :id, :name, :url, :issn_isbn, :publisher_id, {
            :publisher => [:id, :name]
        }, {
            :authority => [:id, :name]
        }, {
            :works => [:id]
        }
    ]

    #Add a response for RSS
    response_for :show do |format|
      format.html #loads show.html.haml (HTML needs to be first, so I.E. views it by default)
      format.rss #loads show.rss.rxml
    end

    response_for :update do |format|
      format.html do
        if params[:save_and_list]
          redirect_to publications_url(:page => @publication.name.first.upcase)
        else
          redirect_to publication_url(@publication)
        end
      end
      format.rss
    end

    before :index do
      # find first letter of publication name (in uppercase, for paging mechanism)
      @a_to_z = Publication.letters(true)

      if params[:q]
        @current_objects = current_objects
      else
        @page = params[:page] || @a_to_z[0]
        #I'm not sure if the first condition here is the same as the authorities scope, but it might be
        @current_objects = Publication.includes(:publisher, :works).where("publications.id = authority_id").
            upper_name_like("#{@page}%").order_by_upper_name
      end

    end

    before :show do
      search(params)
      @publication = @current_object

      @authority_for = Publication.for_authority(@current_object.id).order_by_name
    end

    before :new do
      #Anyone with 'editor' role (anywhere) can add publications
      permit "editor"

      @publishers = Publisher.authorities.order_by_name
      @publications = Publication.authorities.order_by_name
    end

    before :create do
      #Anyone with 'editor' role (anywhere) can add publications
      permit "editor"
    end

    before :edit do
      #Anyone with 'editor' role (anywhere) can update publications
      permit "editor"

      @publishers = Publisher.authorities.order_by_name
      @publications = Publication.order_by_name
    end

    before :update do
      #Anyone with 'editor' role (anywhere) can update publications
      permit "editor"
    end

  end

  def authorities
    #Only group editors can assign authorities
    permit "editor of Group"

    @a_to_z = Publication.letters
    @page = params[:page] || @a_to_z[0]

    if params[:q]
      query = params[:q]
      @current_objects = current_objects
    else
      @current_objects = Publication.authorities.upper_name_like("#{@page}%").order_by_upper_name.
          includes(:authority, {:publisher => :authority}, :works)
    end

    #Keep a list of publications in process in session[:publication_auths]
    #session[:publication_auths].clear
    @pas = Publication.includes(:authority, {:publisher => :authority}, :works).find(session[:publication_auths] || [])
  end

  def add_to_box
    add_to_box_generic(Publication)
  end

  def remove_from_box
    remove_from_box_generic(Publication)
  end

  def update_multiple
    update_multiple_generic(Publication)
  end

  def destroy
    permit "admin"

    publication = Publication.find(params[:id])
    return_path = params[:return_path] || publications_url

    full_success = true

    #Find all works associated with this publication
    works = publication.works

    #Don't allow deletion of publications with works associated
    if works.blank?
      #Destroy the publication
      publication.destroy
    else
      full_success = false
    end

    respond_to do |format|
      if full_success
        flash[:notice] = "Publications were successfully deleted."
        #forward back to path which was specified in params
        format.html { redirect_to return_path }
        format.xml { head :ok }
      else
        flash[:warning] = "This publication has #{works.length} work associated with it, which must be altered or removed before this publication can be deleted."
        format.html { redirect_to edit_publication_path(publication.id) }
        format.xml { head :ok }
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
    @current_objects ||= current_model.where(:issn_isbn => params[:q])
  end
end
