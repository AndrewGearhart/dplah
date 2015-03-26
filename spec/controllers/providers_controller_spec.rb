require 'rails_helper'

# This spec was generated by rspec-rails when you ran the scaffold generator.
# It demonstrates how one might use RSpec to specify the controller code that
# was generated by Rails when you ran the scaffold generator.
#
# It assumes that the implementation code is generated by the rails scaffold
# generator.  If you are using any extension libraries to generate different
# controller code, this generated spec may or may not pass.
#
# It only uses APIs available in rails and/or rspec-rails.  There are a number
# of tools you can use to make these specs even more expressive, but we're
# sticking to rails and rspec-rails APIs to keep things simple and stable.
#
# Compared to earlier versions of this generator, there is very limited use of
# stubs and message expectations in this spec.  Stubs are only used when there
# is no simpler way to get a handle on the object needed for the example.
# Message expectations are only used when there is no simpler way to specify
# that an instance is receiving a specific message.

RSpec.describe ProvidersController, :type => :controller do

  # This should return the minimal set of attributes required to create a valid
  # Provider. As you add validations to Provider, be sure to
  # adjust the attributes here as well.
  let(:valid_attributes) {
   FactoryGirl.build(:provider_small_collection).attributes
  }

  let(:invalid_attributes) {
    skip("Add a hash of attributes invalid for your model")
  }

  # This should return the minimal set of values that should be in the session
  # in order to pass any filters (e.g. authentication) defined in
  # ProvidersController. Be sure to keep this updated too.
  let(:valid_session) { {} }

  before (:each) do
    sign_in FactoryGirl.create(:user)
  end

  describe "GET index" do
    it "assigns all providers as @providers" do
      provider = Provider.create! valid_attributes
      get :index, {}, valid_session
      expect(assigns(:providers)).to eq([provider])
    end
  end

  describe "GET show" do
    it "assigns the requested provider as @provider" do
      provider = Provider.create! valid_attributes
      get :show, {:id => provider.to_param}, valid_session
      expect(assigns(:provider)).to eq(provider)
    end
  end

  describe "GET new" do
    it "assigns a new provider as @provider" do
      get :new, {}, valid_session
      expect(assigns(:provider)).to be_a_new(Provider)
    end
  end

  describe "GET edit" do
    it "assigns the requested provider as @provider" do
      provider = Provider.create! valid_attributes
      get :edit, {:id => provider.to_param}, valid_session
      expect(assigns(:provider)).to eq(provider)
    end
  end

  describe "POST create" do
    describe "with valid params" do
      it "creates a new Provider" do
        expect {
          post :create, {:provider => valid_attributes}, valid_session
        }.to change(Provider, :count).by(1)
      end

      it "assigns a newly created provider as @provider" do
        post :create, {:provider => valid_attributes}, valid_session
        expect(assigns(:provider)).to be_a(Provider)
        expect(assigns(:provider)).to be_persisted
      end

      it "redirects to the created provider" do
        post :create, {:provider => valid_attributes}, valid_session
        expect(response).to redirect_to(Provider.last)
      end
    end

    describe "with invalid params" do
      it "assigns a newly created but unsaved provider as @provider" do
        post :create, {:provider => invalid_attributes}, valid_session
        expect(assigns(:provider)).to be_a_new(Provider)
      end

      it "re-renders the 'new' template" do
        post :create, {:provider => invalid_attributes}, valid_session
        expect(response).to render_template("new")
      end
    end
  end

  describe "PUT update" do
    describe "with valid params" do
      let(:new_attributes) {
        skip("Add a hash of attributes valid for your model")
      }

      it "updates the requested provider" do
        provider = Provider.create! valid_attributes
        put :update, {:id => provider.to_param, :provider => new_attributes}, valid_session
        provider.reload
        skip("Add assertions for updated state")
      end

      it "assigns the requested provider as @provider" do
        provider = Provider.create! valid_attributes
        put :update, {:id => provider.to_param, :provider => valid_attributes}, valid_session
        expect(assigns(:provider)).to eq(provider)
      end

      it "redirects to the provider" do
        provider = Provider.create! valid_attributes
        put :update, {:id => provider.to_param, :provider => valid_attributes}, valid_session
        expect(response).to redirect_to(provider)
      end
    end

    describe "with invalid params" do
      it "assigns the provider as @provider" do
        provider = Provider.create! valid_attributes
        put :update, {:id => provider.to_param, :provider => invalid_attributes}, valid_session
        expect(assigns(:provider)).to eq(provider)
      end

      it "re-renders the 'edit' template" do
        provider = Provider.create! valid_attributes
        put :update, {:id => provider.to_param, :provider => invalid_attributes}, valid_session
        expect(response).to render_template("edit")
      end
    end
  end

  describe "DELETE destroy" do
    it "destroys the requested provider" do
      provider = Provider.create! valid_attributes
      expect {
        delete :destroy, {:id => provider.to_param}, valid_session
      }.to change(Provider, :count).by(-1)
    end

    it "redirects to the providers list" do
      provider = Provider.create! valid_attributes
      delete :destroy, {:id => provider.to_param}, valid_session
      expect(response).to redirect_to(providers_url)
    end
  end

  describe "HARVEST" do
    before (:each) do
      #reset Resquespec
      ResqueSpec.reset!
      # Clean out all records
      ActiveFedora::Base.destroy_all
      # Create initial provider
      @provider = Provider.create! valid_attributes
    end

    it "Harvests all of the data from a provider" do
      sso = stdout_to_null
      VCR.use_cassette "provider_controller/harvest_small_collection" do
        Resque.enqueue(Harvest, @provider)
      end
      $stdout = sso
      expect(Harvest).to have_queue_size_of(1)
    end
  end

  describe "dump and reindex" do
    before (:each) do
      #reset Resquespec
      ResqueSpec.reset!
      # Clean out all records
      ActiveFedora::Base.destroy_all
      # Create initial provider
      @provider = Provider.create! valid_attributes
      # Harvest data
      sso = stdout_to_null
      VCR.use_cassette "provider_controller/harvest_small_collection" do
        post :harvest, {:id => @provider.to_param}, valid_session
      end
      $stdout = sso
    end

    it "Dumps and reindexes by institution" do
      Resque.enqueue(DumpReindex, @provider, "institution")
      expect(DumpReindex).to have_queue_size_of(1)
      expect(response).to redirect_to(providers_url)
    end

    it "Dumps and reindexes by set" do
      Resque.enqueue(DumpReindex, @provider, "set")
      expect(DumpReindex).to have_queue_size_of(1)
      expect(response).to redirect_to(providers_url)
    end
  end

end
