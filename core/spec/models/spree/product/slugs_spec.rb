require 'spec_helper'

describe Spree::Product::Slugs, type: :model do
  let(:store) { Spree::Store.default }

  let(:product) { create(:product, stores: [store], slug: product_slug) }
  let(:product_slug) { nil }

  context 'with not normalized slug' do
    let(:product_slug) { 'hey//joe' }

    it 'normalizes slug on update validation' do
      expect { product.valid? }.to change(product, :slug).to('hey-joe')
    end
  end

  context 'with slug history' do
    before do
      product.update!(name: 'ala', slug: nil)
    end

    it 'updates slugs withs deleted-{id} prefix to ensure uniqueness' do
      expect { product.destroy! }.to change { product.slugs.with_deleted.first.reload.slug }.to a_string_matching(/deleted-\d+_.*/)
    end
  end

  it 'stores old slugs in FriendlyIds history' do
    expect(product).to receive(:create_slug)
    # Set it, otherwise the create_slug method avoids writing a new one
    product.slug = 'custom-slug'
    product.run_callbacks :save
  end

  context 'when product destroyed' do
    it 'renames slug' do
      product.destroy!
      expect(product.slug).to match(/deleted-product-[0-9]+/)
    end

    context 'when more than one translation exists' do
      before do
        product.send(:slug=, 'french-slug', locale: :fr)
        product.save!
      end

      it 'renames slug for all translations' do
        product.destroy!

        expect(product.slug).to match(/deleted-product-[0-9]+/)
        expect(product.translations.with_deleted.where(locale: :fr).first.slug).to match(/deleted-\d+_french-slug/)
      end
    end

    context 'when slug is already at or near max length' do
      before do
        product.slug = nil
        product.name = 'x' * 255
        product.save!
      end

      it 'truncates renamed slug to ensure it remains within length limit' do
        product.destroy!
        expect(product.slug.length).to eq 255
      end
    end
  end

  it 'validates slug uniqueness' do
    existing_product = product
    new_product = create(:product, stores: [store])
    new_product.slug = existing_product.slug

    expect(new_product.valid?).to be false
  end

  it "falls back to 'name-sku' for slug if regular name-based slug already in use" do
    product1 = build(:product, stores: [store])
    product1.name = 'test'
    product1.sku = '123'
    product1.save!

    product2 = build(:product, stores: [store])
    product2.name = 'test'
    product2.sku = '456'
    product2.save!

    expect(product2.slug).to eq 'test-456'
  end

  context 'history' do
    before do
      @product = create(:product, stores: [store])
    end

    it 'keeps the history when the product is destroyed' do
      @product.destroy

      expect(@product.slugs.with_deleted).not_to be_empty
    end

    it 'updates the history when the product is restored' do
      @product.destroy

      @product.restore(recursive: true)

      latest_slug = @product.slugs.find_by slug: @product.slug
      expect(latest_slug).not_to be_nil
    end
  end

  describe '#localized_slugs_for_store' do
    subject { product.localized_slugs_for_store(store) }

    let(:store) { create(:store, default_locale: 'fr', supported_locales: 'en,pl,fr') }
    let(:product) { create(:product, stores: [store], name: 'Test product', slug: 'test-slug-en') }
    let!(:product_translation_fr) { product.translations.create(slug: 'test_slug_fr', locale: 'fr') }

    before { Spree::Locales::SetFallbackLocaleForStore.new.call(store: store) }

    context 'when there are slugs in locales not supported by the store' do
      before do
        product.translations.create!(slug: 'test_slug_pl', locale: 'pl')
        product.translations.create!(slug: 'test_slug_de', locale: 'de')
      end

      let(:expected_slugs) do
        {
          'en' => 'test-slug-en',
          'fr' => 'test-slug-fr',
          'pl' => 'test-slug-pl'
        }
      end

      it 'returns only slugs in locales supported by the store' do
        expect(subject).to match(expected_slugs)
      end
    end

    context 'when one of the supported locales does not have a translation' do
      let(:expected_slugs) do
        {
          'en' => 'test-slug-en',
          'fr' => 'test-slug-fr',
          'pl' => 'test-slug-fr'
        }
      end

      it "falls back to store's default locale" do
        expect(subject).to match(expected_slugs)
      end
    end

    context 'the slugs are generated from name when slug field is empty' do
      before do
        product_translation_fr.update(slug: nil, name: 'slug from name')
      end

      let(:expected_slugs) do
        {
          'en' => 'test-slug-en',
          'fr' => 'slug-from-name',
          'pl' => 'slug-from-name'
        }
      end

      it 'saves slugs generated from name' do
        expect(subject).to match(expected_slugs)
      end
    end

    context 'the slugs are generated from default locale name when name and slug for translation is empty' do
      before do
        product_translation_fr.update(slug: nil, name: nil)
      end

      let(:expected_slugs) do
        {
          'en' => 'test-slug-en',
          'fr' => 'test-product',
          'pl' => 'test-product'
        }
      end

      it 'saves slugs generated from fallback name' do
        expect(subject).to match(expected_slugs)
      end
    end

    context 'the slugs are generated from invalid slug format' do
      before do
        product_translation_fr.update(slug: 'slug with_spaces')
      end

      let(:expected_slugs) do
        {
          'en' => 'test-slug-en',
          'fr' => 'slug-with-spaces',
          'pl' => 'slug-with-spaces'
        }
      end

      it 'saves slugs in valid format' do
        expect(subject).to match(expected_slugs)
      end
    end
  end
end
