import copy
import unittest
from candidate_images import overlay,SERVICES

class CandidateImagesTests(unittest.TestCase):
    def setUp(self):
        self.reference={'items':[{'kind':'Deployment','metadata':{'name':name},'spec':{'template':{'spec':{'containers':[{'name':name,'image':'original@sha256:'+'a'*64,'env':[{'name':'DB_PASSWORD','valueFrom':{'secretKeyRef':{'name':'scoped','key':'password'}}}],'securityContext':{'readOnlyRootFilesystem':True}}],'serviceAccountName':'lab-'+name}}}} for name in SERVICES]}
        self.state={'active':True,'images':{name:'docker.io/library/traderx-security-'+name+'@sha256:'+'b'*64 for name in SERVICES}}
    def test_only_image_and_pull_policy_change_and_reference_is_immutable(self):
        original=copy.deepcopy(self.reference);actual=overlay(self.reference,self.state)
        self.assertEqual(self.reference,original)
        for before,after in zip(original['items'],actual['items']):
            container=after['spec']['template']['spec']['containers'][0]
            self.assertEqual(container.pop('imagePullPolicy'),'IfNotPresent')
            container['image']=before['spec']['template']['spec']['containers'][0]['image']
        self.assertEqual(actual,original)
    def test_invalid_and_partial_pins_are_rejected(self):
        for state in [{'active':True,'images':{}},copy.deepcopy(self.state)]:
            if state['images']:state['images']['trade-service']='docker.io/library/traderx-security-trade-service:latest'
            with self.assertRaises(ValueError):overlay(self.reference,state)
    def test_inactive_state_preserves_reference(self):
        self.assertEqual(overlay(self.reference,{'active':False}),self.reference)
