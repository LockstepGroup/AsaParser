using System;
using System.Xml;
using System.Web;
using System.Security.Cryptography.X509Certificates;
using System.Net;
using System.Net.Security;
using System.IO;
using System.Collections.Generic;
namespace AsaParser {
	public class AccessList {
        public string Name;
        public string Type;
        public List<AccessListRule> Rules;
    }
	public class AccessListRule {
        public string Number;
        public string Remark;
        public string Action;
        public string ProtocolType;
        public string Protocol;
        public string SourceType;
        public string Source;
        public string DestinationType;
        public string Destination;
        public string ServiceType;
        public string Service;
        public bool InActive;
    }
	public class CryptoMap {
        public string Name;
        public List<CryptoMapEntry> Entries;
    }
	public class CryptoMapEntry {
        public int Sequence;
        public string Acl;
        public bool Pfs;
        public string Peer;
        public string TransformSet;
        public int IkeVersion;
    }
	public class Object {
        public string Name;
        public string Description;
        public string Type;
        public List<string> Value;
        public bool IsGroup;
        public string NatSourceInterface;
        public string NatDestinationInterface;
        public string NatType;
        public string NatSourceAddress;
        public string ResolvedNatSourceAddress;
    }
}
