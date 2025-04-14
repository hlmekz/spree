require 'spec_helper'

RSpec.describe Spree::Invitation, type: :model do
  let(:invitation) { create(:invitation) }

  before do
    clear_enqueued_jobs
  end

  describe 'Validations' do
    let(:invitation) { build(:invitation) }

    context 'when invitee is the same as inviter' do
      it 'is invalid' do
        invitation.invitee = invitation.inviter
        expect(invitation).not_to be_valid
        expect(invitation.errors[:invitee]).to include('cannot be the same as the inviter')
      end
    end

    context 'when invitee already exists in the store' do
      it 'is invalid' do
        create(:admin_user, email: 'existing@example.com')
        invitation.email = 'existing@example.com'

        expect(invitation).not_to be_valid
        expect(invitation.errors[:email]).to include('already exists')
      end
    end
  end

  describe 'Callbacks' do
    it 'sets defaults on initialization' do
      invitation = build(:invitation)
      expect(invitation.expires_at).to be_present
    end

    it 'sends invitation email after create' do
      expect { invitation.save }.to have_enqueued_job(ActionMailer::MailDeliveryJob)
    end

    it 'does not send invitation email when skip_email is true' do
      invitation.skip_email = true
      expect { invitation.save }.not_to have_enqueued_job(ActionMailer::MailDeliveryJob)
    end
  end

  describe 'State Machine' do
    it 'has initial state of pending' do
      expect(invitation.status).to eq('pending')
    end

    context 'when accepting an invitation' do
      it 'changes status to accepted' do
        invitation.invitee = create(:admin_user, :no_resource_user)
        invitation.accept
        expect(invitation.status).to eq('accepted')
      end

      it 'sets accepted_at timestamp' do
        expect(invitation.accepted_at).to be_nil
        invitation.invitee = create(:admin_user, :no_resource_user)
        invitation.accept
        expect(invitation.accepted_at).to be_present
      end

      it 'sends acceptance notification' do
        invitation.invitee = create(:admin_user, :no_resource_user)
        clear_enqueued_jobs
        expect { invitation.accept }.to have_enqueued_job(ActionMailer::MailDeliveryJob)
      end

      it 'creates a resource user' do
        invitation.invitee = create(:admin_user, :no_resource_user)
        expect { invitation.accept }.to change(invitation, :resource_user).from(nil).to(Spree::ResourceUser)
        expect(invitation.resource_user.user).to eq(invitation.invitee)
        expect(invitation.resource_user.resource).to eq(invitation.resource)
        expect(invitation.resource_user.invitation).to eq(invitation)
        expect(invitation.resource_user.user.spree_roles).to eq(invitation.roles)
      end
    end
  end

  describe '#expired?' do
    it 'returns true when expires_at is in the past' do
      invitation.expires_at = 1.day.ago
      expect(invitation.expired?).to be true
    end

    it 'returns false when expires_at is in the future' do
      invitation.expires_at = 1.day.from_now
      expect(invitation.expired?).to be false
    end
  end

  describe '#resend!' do
    it 'sends invitation email if invitation is pending and not expired' do
      invitation
      clear_enqueued_jobs
      expect { invitation.resend! }.to have_enqueued_job(ActionMailer::MailDeliveryJob)
    end

    it 'does not send invitation email if invitation is expired' do
      allow(invitation).to receive(:expired?).and_return(true)
      expect(invitation).not_to receive(:send_invitation_email)
      invitation.resend!
    end

    it 'does not send invitation email if invitation is accepted' do
      invitation.invitee = create(:admin_user, :no_resource_user)
      invitation.accept
      expect(invitation).not_to receive(:send_invitation_email)
      invitation.resend!
    end
  end
end
