require 'spec_helper'

describe Neighborly::Api::V1::ChannelsController do
  routes                { Neighborly::Api::Engine.routes }
  let(:parsed_response) { JSON.parse(response.body) }
  let!(:channel)        { FactoryGirl.create(:channel) }

  let(:channels_returned) do
    parsed_response.fetch('channels').map { |t| t['id'] }
  end

  describe '#index', authorized: true do
    let(:do_request) { get :index, format: :json }

    it_behaves_like 'paginating results'

    it 'applies the policy scope' do
      expect(controller).to receive(:policy_scope).with(Channel).and_call_original
      do_request
    end

    it 'filters by query' do
      FactoryGirl.create(:channel, name: 'Ordinary channel')
      channel = FactoryGirl.create(:channel, name: 'Wonderful channel')
      get :index, format: :json, query: 'wonderful'
      expect(channels_returned).to eql([channel.id])
    end

    describe 'filter by state' do
      let!(:draft_channel) do
        FactoryGirl.create(:channel, state: :draft, user: user)
      end

      Channel.state_names.each do |state|
        it "filters by state #{state}" do
          channel      = FactoryGirl.create(:channel, state: state, user: user)
          expected_ids = if state.eql?(:draft)
            [channel.id, draft_channel.id]
          else
            [channel.id]
          end

          get :index, format: :json, state => '1'
          expect(channels_returned).to include(*expected_ids)
        end
      end
    end
  end

  describe '#show', authorized: true do
    let(:do_request) { get :show, id: channel.id, format: :json }

    it 'responds with 200' do
      do_request
      expect(response.status).to eql(200)
    end

    it 'has a top level element called channel' do
      do_request
      expect(parsed_response.fetch('channel')).to be_a(Hash)
    end

    it 'responds with data of the given channel' do
      do_request
      expect(
        parsed_response.fetch('channel')
      ).to have_key('id')
    end
  end

  describe 'destroy', authorized: true, admin: true do
    let(:do_request) { delete :destroy, id: channel.id, format: :json }

    it 'returns a success http status' do
      do_request
      expect(response.status).to eq(204)
      expect{ channel.reload }.to raise_error
    end
  end

  [:push_to_draft, :push_to_online].each do |name|
    describe "#{name}", authorized: true, admin: true do
      let(:user)       { FactoryGirl.create(:user, admin: true) }
      let(:channel)    { FactoryGirl.create(:channel, state: 'draft') }
      let(:do_request) { put name, id: channel.id, format: :json }

      it 'returns a success http status' do
        do_request
        expect(response.status).to eq(204)
      end

      it 'authorizes the resource' do
        expect(controller).to receive(:authorize).with(channel)
        do_request
      end

      it 'calls the state machine helper to change the state' do
        expect_any_instance_of(Channel).to receive("#{name}!")
        do_request
      end
    end
  end
end
