using System;
using System.Collections.Generic;
using System.IO;
using System.Net;
using System.Net.Security;
using System.Security.Cryptography.X509Certificates;
using System.Xml;
using System.Web;

namespace AsaParser {
	public class CryptoMapEntry {
        public int Sequence;
        public string Acl;
        public bool Pfs;
        public string Peer;
        public string TransformSet;
    }
}