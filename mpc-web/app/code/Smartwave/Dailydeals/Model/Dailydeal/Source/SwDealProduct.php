<?php
namespace Smartwave\Dailydeals\Model\Dailydeal\Source;

class SwDealProduct implements \Magento\Framework\Option\ArrayInterface
{
    const FIXED = 1;
    const PERCENTAGE = 2;

    /**
     * to option array
     *
     * @return array
     */
    protected $productFactory;
    protected $_collection;
    

    public function __construct(
		\Magento\Catalog\Model\ResourceModel\Product\Collection $collection, 
        \Magento\Catalog\Model\ProductFactory $productFactory
    ) {
		$this->_collection = $collection;
        $this->productFactory=$productFactory;
    }


    public function toOptionArray()
    {

        $childArray=[];

        $productcollection=clone $this->_collection;
        $productcollection->clear()->getSelect()->reset(\Magento\Framework\DB\Select::WHERE)->reset(\Magento\Framework\DB\Select::ORDER)->reset(\Magento\Framework\DB\Select::LIMIT_COUNT)->reset(\Magento\Framework\DB\Select::LIMIT_OFFSET)->reset(\Magento\Framework\DB\Select::GROUP);
		$productcollection->addMinimalPrice()
                ->addFinalPrice()
                ->addTaxPercents()
                ->addAttributeToSelect('name')
                ->addAttributeToSelect('image')
                ->addAttributeToSelect('small_image')
                ->addAttributeToSelect('thumbnail')
                ->addUrlRewrite()
                ->addAttributeToSort('created_at','asc');
		$objectManager = \Magento\Framework\App\ObjectManager::getInstance();
        $currencySymbol=$objectManager->create('Magento\Store\Model\StoreManagerInterface');
        $currencysymbol=$currencySymbol->getStore()->getCurrentCurrency()->getCurrencySymbol();

        $options = ['value'=>'','label'=>'-- Select Product --'];
        foreach ($productcollection as $product) {
			$sku=$product->getSku();
			$name=$product->getName();
			$id=$product->getId();
			$price=$product->getFinalPrice();

            if ($price != 0) {
                $options[] =
                [ 'value'=>$sku,
                'label'=>"ID:".$id."  ".$name."- ".$currencysymbol."".round($price, 2)." "
                ];
            }
        }

        $unique = array_map("unserialize", array_unique(array_map("serialize", $options)));

        return $unique;
    }
}
